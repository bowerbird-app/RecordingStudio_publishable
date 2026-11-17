# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  # nil follows RecordingStudio.configuration.layout, then recording_studio/default_layout.
  config.layout = nil

  config.after_switch_redirect = lambda do |controller:, return_to:, **|
    candidate_path = return_to.presence
    candidate_path = controller.main_app.root_path if candidate_path.blank?

    if internal_route?(candidate_path)
      candidate_path
    else
      controller.main_app.root_path
    end
  end

  config.scope :all_workspaces do |scope|
    scope.label = "All workspaces"
    scope.description = "Every workspace in the dummy app."
    scope.available_roots = lambda do |**|
      Workspace.order(:name).filter_map do |workspace|
        RecordingStudio.root_recording_for(workspace)
      end
    end
    scope.access_check = ->(**) { true }

    scope.default_root = lambda do |roots:, **|
      roots.first
    end
  end
end

# Public cached pages skip the device cookie. Registered once when the
# controller class loads. The condition runs per request and does not
# change the callback chain.
module DummyPublicHttpCacheRoot
  def dummy_public_http_cache?
    policy = RecordingStudioPublishable::HttpCache.fetch_policy(self)
    policy.respond_to?(:public?) && policy.public?
  end
end

Rails.application.config.to_prepare do
  controller = RecordingStudioPublishable::PublishedController
  next unless controller.respond_to?(:skip_recording_studio_root_resolution)
  next if controller.include?(DummyPublicHttpCacheRoot)

  controller.include(DummyPublicHttpCacheRoot)
  controller.skip_recording_studio_root_resolution(raise: false, if: :dummy_public_http_cache?)
end

def internal_route?(path)
  routes = [
    Rails.application.routes,
    RecordingStudioRootSwitchable::Engine.routes
  ]

  routes.any? do |route_set|
    route_set.recognize_path(path, method: :get)
    true
  rescue StandardError
    false
  end
end
