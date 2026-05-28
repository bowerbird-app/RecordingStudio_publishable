# frozen_string_literal: true

RecordingStudioPublishable.configure do |config|
  # Use a host-app resolver that returns the current actor used for publishable management.
  # config.current_actor_resolver = ->(controller:) { Current.actor || controller.current_user }

  # Authorize management actions against the parent recording.
  # When RecordingStudioAccessible is installed, the default authorizer uses it automatically.
  # config.management_authorizer = lambda do |recording:, actor:, controller:|
  #   actor.present? && RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :edit)
  # end

  # Use the host app's preferred default time zone for schedule editing.
  # config.default_time_zone = "UTC"

  # Override the engine layout used by all gem-managed screens.
  # config.layout = "application"

  # Configure the PageNav close URL used on publishable edit/success screens.
  # Defaults to the host app root path.
  # config.management_close_url_resolver = ->(controller:, recording:) { controller.main_app.root_path }

  # Override the backend controller/action used to prepare and render a parent type
  # on the published route without changing the public URL.
  # The default convention resolves Page -> pages#show, Article -> articles#show.
  # config.register_public_renderer("Page", controller: "pages", action: :show, layout: "application")

  # Change the redirect status used when a stale slug is requested.
  # config.canonical_redirect_status = :moved_permanently
end
