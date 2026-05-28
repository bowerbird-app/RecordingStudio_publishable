Rails.application.routes.draw do
  mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
  devise_for :users

  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioPublishable::Engine, at: "/"

  get "up" => "rails/health#show", as: :rails_health_check

  get "docs/install", to: "docs#install", as: :docs_install
  get "docs/config", to: "docs#configuration", as: :docs_config
  get "docs/setup", to: "docs#setup", as: :docs_setup
  get "docs/recordable_types", to: "docs#recordable_types", as: :docs_recordable_types
  get "docs/recordings_tree", to: "docs#recordings_tree", as: :docs_recordings_tree
  get "docs/gem_views", to: "docs#gem_views", as: :docs_gem_views
  get "docs/methods", to: "docs#methods", as: :docs_methods
  get "docs/headers", to: "docs#headers", as: :docs_headers
  get "docs/components", to: "docs#components", as: :docs_components

  get "/dummy/pages/new", to: "dummy_pages#new", as: :new_dummy_page
  post "/dummy/pages", to: "dummy_pages#create", as: :dummy_pages

  root "home#index"
end
