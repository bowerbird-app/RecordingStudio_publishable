class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport
  include RecordingStudio::UsesDefaultLayout

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes if respond_to?(:stale_when_importmap_changes)

  # Devise keeps the sign-in layout. Every authenticated host page uses
  # RecordingStudio::UsesDefaultLayout (`recording_studio/default_layout`).
  layout :application_layout

  before_action :authenticate_user!
  before_action :set_current_actor

  private

  def application_layout
    devise_controller? ? "application" : "recording_studio/default_layout"
  end

  def set_current_actor
    Current.actor = RecordingStudio::ActorResolver.resolve_actor.call(current_user)
    Current.impersonator = nil
  end
end
