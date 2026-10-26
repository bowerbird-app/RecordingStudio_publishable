class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes if respond_to?(:stale_when_importmap_changes)

  recording_studio_layout { devise_controller? ? "application" : nil }

  before_action :authenticate_user!
  before_action :set_current_actor

  private

  def set_current_actor
    Current.actor = RecordingStudio::ActorResolver.resolve_actor.call(current_user)
    Current.impersonator = nil
  end
end
