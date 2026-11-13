# frozen_string_literal: true

require "test_helper"

class PublishableApiActionsTest < ActionDispatch::IntegrationTest
  PUBLISH_PATH = "/recording_studio_api/api/v1/articles/{id}/actions/publish"
  RESPONSE_KEYS = %w[
    id type parent_id root_id created_at updated_at
    publishable_recording_id status slug seo_title social_title publish_at
  ].freeze

  setup do
    @user = User.create!(
      email: "publishable-api-#{SecureRandom.hex(4)}@example.com",
      password: "PublishableApiPassword!2026",
      password_confirmation: "PublishableApiPassword!2026"
    )
    Current.actor = @user
    @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "API workspace"))
    @access = owner_access(@root)
    @article = RecordingStudio::Recording.create!(
      recordable: Article.create!(title: "Launch"),
      parent_recording: @root
    )
    RecordingStudio.enable_capability(:api_access_point, on: "Workspace")
    register_article_api!
    @token = bearer_token(@access)
  end

  teardown do
    Current.actor = nil
  end

  test "openapi publish response includes the recording envelope and publishable fields" do
    properties = openapi_properties(PUBLISH_PATH, "post")

    RESPONSE_KEYS.each do |key|
      assert properties.key?(key), "OpenAPI publish response is missing #{key}"
    end
    assert_equal "string", properties.dig("id", "type")
    assert_equal "date-time", properties.dig("created_at", "format")
    assert_equal true, properties.dig("parent_id", "nullable")
    assert_equal %w[draft published scheduled], properties.dig("status", "enum")
  end

  test "post publish publishes the parent through the api route" do
    path = action_path(@article, "publish")

    post path, headers: bearer_headers, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @article.id, body.fetch("id")
    assert_equal "Article", body.fetch("type")
    assert_equal @root.id, body.fetch("parent_id")
    assert_equal @root.id, body.fetch("root_id")
    assert_equal "published", body.fetch("status")
    assert body.fetch("publish_at").present?
    publishable = @article.reload.current_publishable
    assert_equal "published", publishable.status
    assert_in_delta Time.current.to_f, publishable.publish_at.to_f, 5
  end

  test "post unpublish returns the parent to draft" do
    post action_path(@article, "publish"), headers: bearer_headers, as: :json
    assert_response :success

    post action_path(@article, "unpublish"), headers: bearer_headers, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @article.id, body.fetch("id")
    assert_equal "draft", body.fetch("status")
    assert_nil body.fetch("publish_at")
    assert_equal "draft", @article.reload.current_publishable.status
    assert_nil @article.current_publishable.publish_at
  end

  test "openapi unpublish and update_publishable 200 schemas include the snapshot keys" do
    unpublish = openapi_properties("/recording_studio_api/api/v1/articles/{id}/actions/unpublish", "post")
    update = openapi_properties("/recording_studio_api/api/v1/articles/{id}/actions/update_publishable", "patch")
    keys = RecordingStudioPublishable::Api::PublishableSnapshot.schema_properties.keys.map(&:to_s)

    keys.each do |key|
      assert unpublish.key?(key), "OpenAPI unpublish response is missing #{key}"
      assert update.key?(key), "OpenAPI update_publishable response is missing #{key}"
    end
  end

  test "update_publishable openapi fields use the approved wording" do
    properties = openapi_request_properties(
      "/recording_studio_api/api/v1/articles/{id}/actions/update_publishable",
      "patch"
    )

    assert_equal(
      RecordingStudioPublishable::Api::PublishableSnapshot::FIELDS.dig(:status, :description),
      properties.dig("status", "description") || properties.dig("status", :description)
    )
    assert_equal(
      RecordingStudioPublishable::Api::PublishableSnapshot::FIELDS.dig(
        :social_image_attachment_recording_id, :description
      ),
      properties.dig("social_image_attachment_recording_id", "description") ||
        properties.dig("social_image_attachment_recording_id", :description)
    )
  end

  test "a second publish on a live article leaves publish times unchanged" do
    freeze_time do
      post action_path(@article, "publish"), headers: bearer_headers, as: :json
      assert_response :success
      patch action_path(@article, "update_publishable"),
            params: { unpublish_at: 1.day.from_now.iso8601, time_zone: "UTC" },
            headers: bearer_headers,
            as: :json
      assert_response :success
      publishable = @article.reload.current_publishable
      publish_at = publishable.publish_at
      unpublish_at = publishable.unpublish_at

      travel 1.minute
      post action_path(@article, "publish"), headers: bearer_headers, as: :json

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "published", body.fetch("status")
      assert_equal publish_at.to_i, Time.iso8601(body.fetch("publish_at")).to_i
      assert_equal unpublish_at.to_i, Time.iso8601(body.fetch("unpublish_at")).to_i
      assert_equal publish_at, @article.reload.current_publishable.publish_at
      assert_equal unpublish_at, @article.current_publishable.unpublish_at
    end
  end

  test "a second unpublish on a draft article does not write" do
    freeze_time do
      patch action_path(@article, "update_publishable"),
            params: { slug: "held" },
            headers: bearer_headers,
            as: :json
      assert_response :success
      publishable = @article.reload.current_publishable
      updated_at = publishable.updated_at
      child_id = @article.publishable_child_recording.id

      travel 1.minute
      post action_path(@article, "unpublish"), headers: bearer_headers, as: :json

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "draft", body.fetch("status")
      assert_nil body.fetch("publish_at")
      assert_equal updated_at, @article.reload.current_publishable.updated_at
      assert_equal child_id, @article.publishable_child_recording.id
    end
  end

  test "unpublish without a publishable child does not create one" do
    count = RecordingStudioPublishable::Publishable.count

    post action_path(@article, "unpublish"), headers: bearer_headers, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @article.id, body.fetch("id")
    assert_equal "draft", body.fetch("status")
    assert_nil body.fetch("publishable_recording_id")
    assert_nil @article.reload.current_publishable
    assert_equal count, RecordingStudioPublishable::Publishable.count
  end

  test "an empty update_publishable still saves" do
    freeze_time do
      patch action_path(@article, "update_publishable"),
            params: { slug: "held" },
            headers: bearer_headers,
            as: :json
      assert_response :success
      updated_at = @article.reload.current_publishable.updated_at

      travel 1.minute
      patch action_path(@article, "update_publishable"), params: {}, headers: bearer_headers, as: :json

      assert_response :success
      assert_operator @article.reload.current_publishable.updated_at, :>, updated_at
    end
  end

  test "patch update_publishable writes seo and social titles" do
    patch action_path(@article, "update_publishable"),
          params: { seo_title: "Launch", social_title: "Share launch" },
          headers: bearer_headers,
          as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @article.id, body.fetch("id")
    assert_equal "Launch", body.fetch("seo_title")
    assert_equal "Share launch", body.fetch("social_title")
    publishable = @article.reload.current_publishable
    assert_equal "Launch", publishable.seo_title
    assert_equal "Share launch", publishable.social_title
  end

  private

  def register_article_api!
    RecordingStudioApi.register_recordable_type_api(
      "Article",
      capability_actions: %i[publish unpublish update_publishable]
    )
  end

  def action_path(recording, action_name)
    path = recording_studio_api.api_v1_resource_action_path("articles", recording.id, action_name)
    assert_equal "/recording_studio_api/api/v1/articles/#{recording.id}/actions/#{action_name}", path
    path
  end

  def bearer_headers
    { "Authorization" => "Bearer #{@token}" }
  end

  def openapi_properties(path, verb)
    openapi_operation(path, verb).dig(:responses, "200", "content", "application/json", "schema", "properties")
  end

  def openapi_request_properties(path, verb)
    openapi_operation(path, verb).dig(
      :requestBody, :content, "application/json", :schema, :properties
    ) || openapi_operation(path, verb).dig(
      "requestBody", "content", "application/json", "schema", "properties"
    )
  end

  def openapi_operation(path, verb)
    document = RecordingStudioApi.openapi_document
    operation = document.dig(:paths, path, verb) || document.dig(:paths, path, verb.to_sym)
    if operation.nil?
      known = document.fetch(:paths).keys.grep(/publish/)
      flunk("missing OpenAPI operation #{verb} #{path}. publish paths: #{known.join(', ')}")
    end

    operation
  end

  def owner_access(recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: @user)
    result.respond_to?(:value!) ? result.value! : result
  end

  def bearer_token(access_recording)
    payload = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: access_recording.recordable.actor,
      role: access_recording.recordable.role,
      name: "Publishable integration"
    )
    raise payload.error unless payload.success?

    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: payload.value.fetch(:credential).oauth_client_id,
      client_secret: payload.value.fetch(:token)
    )
    raise token_result.error unless token_result.success?

    token_result.value.fetch(:access_token)
  end
end
