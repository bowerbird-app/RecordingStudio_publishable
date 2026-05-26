# frozen_string_literal: true

RecordingStudioPublishable::Engine.routes.draw do
  get "/recordings/:recording_id/publishable/edit", to: "publishables#edit", as: :edit_recording_publishable
  patch "/recordings/:recording_id/publishable", to: "publishables#update", as: :publishable
  patch "/recordings/:recording_id/publishable/:transition", to: "publishables#transition",
                                                             as: :transition_recording_publishable
  get "/published/:uuid/:slug", to: "published#show", as: :publication

  RecordingStudioPublishable.configuration.public_path_configs.each do |recordable_type, path_template|
    next if path_template == RecordingStudioPublishable::Configuration::DEFAULT_PUBLIC_PATH

    url_enabled = if RecordingStudioPublishable.configuration.respond_to?(:public_url_enabled_for)
      RecordingStudioPublishable.configuration.public_url_enabled_for(recordable_type)
    else
      true
    end
    next unless url_enabled

    get path_template, to: "published#show", defaults: { parent_recordable_type: recordable_type }
  end
end
