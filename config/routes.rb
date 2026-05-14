# frozen_string_literal: true

RecordingStudioPublishable::Engine.routes.draw do
  get "/recordings/:recording_id/publishable/edit", to: "publishables#edit", as: :edit_recording_publishable
  patch "/recordings/:recording_id/publishable", to: "publishables#update", as: :publishable
  patch "/recordings/:recording_id/publishable/:transition", to: "publishables#transition",
                                                             as: :transition_recording_publishable
  get "/published/:uuid/:slug", to: "published#show", as: :publication
end
