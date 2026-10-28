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

  test "engine registration is idempotent against the real RecordingStudioApi" do
    first = RecordingStudioPublishable::Api.register_capability_action!
    second = RecordingStudioPublishable::Api.register_capability_action!

    assert_nil first
    assert_nil second
    assert publishable_capability_action(:publish)
    assert publishable_capability_action(:unpublish)
    assert publishable_capability_action(:update_publishable)
  end

  test "update contract strips route keys and rejects an unknown key" do
    contract = action_input_contract(:update_publishable)
    stripped = contract.call(
      "slug" => "launch",
      "api_key" => "public",
      api_version: "v1",
      member_action: { "slug" => "launch" }
    )
    unknown = contract.call(slug: "launch", api_key: "public", "api_version" => "v1", extra: true)

    assert_operator contract.class, :<, RecordingStudioApi::ActionInputContract
    assert_equal({ slug: "launch" }, stripped.value)
    assert_equal ["Unknown parameters: extra"], unknown.errors
  end

  test "publish contract rejects status" do
    publish_contract = action_input_contract(:publish)
    result = publish_contract.call(status: "published")

    assert_same publish_contract, action_input_contract(:unpublish)
    assert_equal ["Unknown parameters: status"], result.errors
  end

  test "update contract accepts slug and scheduled status" do
    contract = action_input_contract(:update_publishable)
    accepted = contract.call(slug: "launch", status: "scheduled", api_key: "public", "api_version" => "v1")
    blank = contract.call(status: "")
    unknown = contract.call(slug: "launch", extra: "no")

    assert_equal [], accepted.errors
    assert_equal({ slug: "launch", status: "scheduled" }, accepted.value)
    assert_equal ["status must be one of: draft, published, scheduled"], blank.errors
    assert_equal ["Unknown parameters: extra"], unknown.errors
  end

  test "invalid input raises RecordingStudioApi::InvalidActionInputError" do
    error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      RecordingStudioPublishable::Api.invalid_input!("Social image is invalid", details: ["Social image is invalid"])
    end

    assert_equal "Social image is invalid", error.message
    assert_equal ["Social image is invalid"], error.details
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

  def action_input_contract(name)
    action = publishable_capability_action(name)
    contract = if action.respond_to?(:fetch)
                 action.fetch(:input_contract)
               elsif action.respond_to?(:input_contract)
                 action.input_contract
               elsif action.respond_to?(:[])
                 action[:input_contract]
               end
    flunk("missing input_contract on #{name}") if contract.blank?
    contract
  end

  def publishable_capability_action(name)
    action = if named_api_registration?
               found = nil
               RecordingStudioApi.configuration.each_api do |definition|
                 found = RecordingStudioApi.capability_action(name, api: definition.name)
                 break if found
               end
               found
             else
               RecordingStudioApi.capability_action(name)
             end
    flunk("missing RecordingStudioApi capability action #{name}") if action.blank?
    action
  end

  def named_api_registration?
    RecordingStudioApi.respond_to?(:configuration) &&
      RecordingStudioApi.configuration.respond_to?(:each_api) &&
      RecordingStudioApi.method(:capability_action).parameters.any? do |type, parameter_name|
        type == :keyrest || (parameter_name == :api && %i[key keyreq].include?(type))
      end
  end

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
    document = RecordingStudioApi.openapi_document
    operation = document.dig(:paths, path, verb)
    if operation.nil?
      known = document.fetch(:paths).keys.grep(/publish/)
      flunk("missing OpenAPI operation #{verb} #{path}. publish paths: #{known.join(', ')}")
    end

    operation.dig(:responses, "200", "content", "application/json", "schema", "properties")
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
