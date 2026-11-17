# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"
require "devise/test/integration_helpers"
require "rails/test_help"
require "securerandom"

module PublishedHttpCacheProbes
  def mint_publishable_cache_probe_cookie
    return unless Thread.current[:publishable_test_host_cookie]

    cookies[:host_marker] = "minted"
  end

  def install_publishable_cache_probe_csp
    return unless Thread.current[:publishable_test_nonce_csp]

    policy = ActionDispatch::ContentSecurityPolicy.new
    policy.default_src :self
    policy.script_src :self
    request.content_security_policy = policy
    request.content_security_policy_nonce_directives = %w[script-src]
    request.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  end

  def resolve_recording_studio_root_switchable_current
    Thread.current[:publishable_root_resolution_calls] =
      Thread.current[:publishable_root_resolution_calls].to_i + 1
    super
  end
end

module ArticleShowProbe
  def show
    Thread.current[:publishable_article_shows] = Thread.current[:publishable_article_shows].to_i + 1
    super
  end
end

RecordingStudioPublishable::PublishedController.prepend(PublishedHttpCacheProbes)
RecordingStudioPublishable::PublishedController.before_action :mint_publishable_cache_probe_cookie
RecordingStudioPublishable::PublishedController.before_action :install_publishable_cache_probe_csp
ArticlesController.prepend(ArticleShowProbe)

class PublishedHttpCacheTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "PublishableCachePassword!2026"

  teardown do
    Thread.current[:publishable_test_host_cookie] = nil
    Thread.current[:publishable_test_nonce_csp] = nil
    Thread.current[:publishable_root_resolution_calls] = nil
    Thread.current[:publishable_article_shows] = nil
  end

  test "default published page stays private with no etag" do
    page = publish_page("Private page", slug: "private-page")

    with_forgery_protection do
      get "/published/#{page.fetch(:publishable).id}/private-page"
    end

    assert_response :success
    assert_no_store
    assert_predicate etag_header, :blank?
    assert_includes response.body, "csrf-token"
  end

  test "a nil hook and a session viewer are no-store" do
    page = publish_page("Session page", slug: "session-page")
    path = "/published/#{page.fetch(:publishable).id}/session-page"

    get path
    assert_response :success
    assert_no_store
    assert_predicate etag_header, :blank?

    sign_in_editor
    get path
    assert_response :success
    assert_no_store
    assert_predicate etag_header, :blank?

    article = publish_article("Nil policy", slug: "nil-policy")
    with_article_http_cache(->(_request) {}) do
      get article_path(article)
      assert_response :success
      assert_no_store
      assert_predicate etag_header, :blank?
    end
  end

  test "the hook can read Current.actor and keep a signed-in viewer private" do
    article = publish_article("Actor article", slug: "actor-article")
    path = article_path(article)
    policy = RecordingStudioPublishable::HttpCachePolicy.new(public: true, max_age: 30, etag: "actor")

    with_article_http_cache(lambda { |_request|
      Current.actor.present? ? nil : policy
    }) do
      get path
      assert_response :success
      assert_includes cache_control, "public"
      assert_includes cache_control, "max-age=30"
      refute_includes cache_control, "stale-while-revalidate"

      sign_in_editor
      get path
      assert_response :success
      assert_no_store
      assert_predicate etag_header, :blank?
    end
  end

  test "a custom max age omits stale while revalidate" do
    article = publish_article("Short cache", slug: "short-cache")
    policy = RecordingStudioPublishable::HttpCachePolicy.new(public: true, max_age: 45, etag: "short")

    with_article_http_cache(->(_request) { policy }) do
      get article_path(article)
    end

    assert_response :success
    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=45"
    refute_includes cache_control, "stale-while-revalidate"
    refute_includes cache_control, "private"
  end

  test "opted-in published page is public, stable, and returns 304 without a cookie" do
    article = publish_article("Cached article", slug: "cached-article")
    path = article_path(article)

    with_forgery_protection do
      Thread.current[:publishable_article_shows] = 0
      get path
      assert_response :success
      assert_public_cache
      refute_includes response.body, "csrf-token"
      refute_includes response.body, "csp-nonce"
      first_body = response.body
      first_etag = etag_header
      refute_set_cookie
      assert_equal 1, Thread.current[:publishable_article_shows]

      get path
      assert_response :success
      assert_equal first_etag, etag_header
      assert_equal first_body, response.body
      assert_public_cache

      shows_before_not_modified = Thread.current[:publishable_article_shows]
      get path, headers: { "If-None-Match" => first_etag }
      assert_response :not_modified
      assert_equal first_etag, etag_header
      assert_public_cache
      refute_set_cookie
      refute_includes response.body.to_s, "Cached article"
      assert_equal shows_before_not_modified, Thread.current[:publishable_article_shows]
    end
  end

  test "unpublished and missing pages stay no-store with an old etag" do
    article = publish_article("Hidden article", slug: "hidden-article")
    path = article_path(article)

    get path
    assert_response :success
    previous_etag = etag_header
    assert previous_etag.present?

    RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: article.fetch(:parent),
      transition: "unpublish"
    ).value!

    get path, headers: { "If-None-Match" => previous_etag }
    assert_response :not_found
    assert_no_store
    refute_equal previous_etag, etag_header

    get "/published/#{SecureRandom.uuid}/missing", headers: { "If-None-Match" => previous_etag }
    assert_response :not_found
    assert_no_store
  end

  test "preview is never cached" do
    article = publish_article("Preview article", slug: "preview-article")

    get article_path(article)
    public_etag = etag_header
    assert_public_cache

    editor = sign_in_editor
    access = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: article.fetch(:root),
      actor: editor
    )
    access.value! if access.respond_to?(:value!)

    get recording_studio_publishable.preview_recording_publishable_path(recording_id: article.fetch(:parent).id),
        headers: { "If-None-Match" => public_etag }

    assert_response :success
    assert_no_store
    refute_equal public_etag, etag_header
    assert_includes response.body, "Preview article"
  end

  test "etag changes after an edit and after unpublish and republish" do
    article = publish_article("Versioned article", slug: "versioned-article")
    path = article_path(article)

    get path
    original = etag_header

    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: article.fetch(:parent),
      attributes: { slug: "versioned-article", status: "published", seo_title: "Edited SEO" }
    ).value!

    get path
    edited = etag_header
    refute_equal original, edited
    assert_public_cache

    RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: article.fetch(:parent),
      transition: "unpublish"
    ).value!
    RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: article.fetch(:parent),
      transition: "publish"
    ).value!

    get path
    assert_public_cache
    refute_equal edited, etag_header
    refute_equal original, etag_header
  end

  test "a public response strips a host cookie" do
    article = publish_article("Cookie article", slug: "cookie-article")
    Thread.current[:publishable_test_host_cookie] = true
    Thread.current[:publishable_root_resolution_calls] = 0

    get article_path(article)

    assert_response :success
    assert_public_cache
    refute_set_cookie
    assert_equal 0, Thread.current[:publishable_root_resolution_calls]
  end

  test "a private page still resolves the root" do
    page = publish_page("Root page", slug: "root-page")
    Thread.current[:publishable_root_resolution_calls] = 0

    get "/published/#{page.fetch(:publishable).id}/root-page"

    assert_response :success
    assert_no_store
    assert_operator Thread.current[:publishable_root_resolution_calls], :>=, 1
  end

  test "a public response drops a nonce content security policy" do
    page = publish_page("Nonce page", slug: "nonce-page")
    article = publish_article("Nonce article", slug: "nonce-article")
    Thread.current[:publishable_test_nonce_csp] = true

    get "/published/#{page.fetch(:publishable).id}/nonce-page"
    assert_response :success
    assert_includes csp_header, "nonce-"

    get article_path(article)
    assert_response :success
    assert_public_cache
    assert_predicate csp_header, :blank?
    refute_includes response.body, "csp-nonce"
  end

  private

  def publish_page(title, slug:)
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Cache workspace #{slug}"))
    parent = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: title),
      parent_recording: root
    )
    publishable = publish(parent, slug: slug)
    { root: root, parent: parent, publishable: publishable }
  end

  def publish_article(title, slug:)
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Cache workspace #{slug}"))
    parent = RecordingStudio::Recording.create!(
      recordable: Article.create!(title: title),
      parent_recording: root
    )
    publishable = publish(parent, slug: slug)
    { root: root, parent: parent, publishable: publishable }
  end

  def publish(parent, slug:)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent,
      attributes: { slug: slug, status: "published" }
    ).value!
  end

  def article_path(article)
    "/blogs/#{article.fetch(:publishable).id}/#{article.fetch(:publishable).recordable.slug}"
  end

  def with_article_http_cache(implementation)
    Article.class_eval do
      alias_method :publishable_http_cache_original, :publishable_http_cache
      define_method(:publishable_http_cache, &implementation)
    end
    yield
  ensure
    Article.class_eval do
      alias_method :publishable_http_cache, :publishable_http_cache_original
      remove_method :publishable_http_cache_original
    end
  end

  def cache_control
    response.headers["Cache-Control"].to_s
  end

  def csp_header
    response.headers["Content-Security-Policy"].to_s
  end

  def etag_header
    response.headers["ETag"].to_s
  end

  def assert_public_cache
    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "stale-while-revalidate=60"
    assert_equal "Accept-Encoding", response.headers["Vary"]
    assert_match(/\A"[0-9a-f]{64}"\z/, etag_header)
    refute_includes cache_control, "private"
  end

  def assert_no_store
    assert_includes cache_control, "private"
    assert_includes cache_control, "no-store"
    refute_includes cache_control, "public"
  end

  def refute_set_cookie
    header = response.headers["Set-Cookie"]
    values = header.is_a?(Array) ? header : [header]
    assert values.all?(&:blank?), "expected no Set-Cookie, got #{header.inspect}"
  end

  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  def forgery_meta_tags?
    ActionController::Base.allow_forgery_protection
  end

  def sign_in_editor
    email = "publishable-cache-#{SecureRandom.hex(4)}@example.com"
    user = User.create!(
      email: email,
      password: TEST_PASSWORD,
      password_confirmation: TEST_PASSWORD
    )
    sign_in user
    user
  end
end
