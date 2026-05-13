# frozen_string_literal: true

require_relative "hooks"

module RecordingStudioPublishable
  class Configuration
    DEFAULT_PUBLIC_PATH = "/published/:uuid/:slug"

    attr_accessor :current_actor_resolver,
                  :management_authorizer,
                  :default_time_zone,
                  :default_layout,
                  :canonical_redirect_status
    attr_reader :hooks, :public_path_configs

    def initialize
      @current_actor_resolver = method(:default_current_actor_resolver)
      @management_authorizer = method(:default_management_authorizer)
      @default_time_zone = default_rails_time_zone
      @default_layout = "recording_studio_publishable/application"
      @canonical_redirect_status = :found
      @public_path_configs = {}
      @hooks = Hooks.new
    end

    def to_h
      {
        default_time_zone: default_time_zone,
        default_layout: default_layout,
        canonical_redirect_status: canonical_redirect_status,
        public_path_configs: public_path_configs.dup,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    def register_public_path(recordable_type, path: DEFAULT_PUBLIC_PATH)
      public_path_configs[normalize_recordable_type(recordable_type)] = path
    end

    def public_path_for(recordable_type)
      public_path_configs[normalize_recordable_type(recordable_type)] || DEFAULT_PUBLIC_PATH
    end

    def authorize_management?(recording:, actor:, controller: nil)
      resolve_callable(
        management_authorizer,
        recording: recording,
        actor: actor,
        controller: controller
      )
    end

    def actor_for(controller: nil)
      resolve_callable(current_actor_resolver, controller: controller)
    end

    private

    def default_current_actor_resolver(controller: nil)
      current_actor = Current.actor if defined?(Current) && Current.respond_to?(:actor)
      return current_actor if current_actor.present?
      return unless controller&.respond_to?(:current_user, true)

      controller.send(:current_user)
    rescue StandardError
      nil
    end

    def default_management_authorizer(recording:, actor:, controller: nil)
      actor ||= actor_for(controller: controller)
      return false unless actor.present? && recording.present?

      if defined?(RecordingStudioAccessible) && RecordingStudioAccessible.respond_to?(:authorized?)
        return RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :edit)
      end

      false
    rescue StandardError
      false
    end

    def default_rails_time_zone
      return Time.zone.name if Time.respond_to?(:zone) && Time.zone.respond_to?(:name)
      return Rails.application.config.time_zone if defined?(Rails) && Rails.application&.config&.respond_to?(:time_zone)

      "UTC"
    rescue StandardError
      "UTC"
    end

    def normalize_recordable_type(recordable_type)
      recordable_type.is_a?(Class) ? recordable_type.name : recordable_type.to_s
    end

    def resolve_callable(callable, **kwargs)
      return unless callable

      parameters = callable.parameters
      return callable.call(**kwargs) if parameters.any? { |type, _| type == :keyrest }

      supported = parameters.filter_map { |type, name| name if %i[key keyreq].include?(type) }
      callable.call(**kwargs.slice(*supported))
    end
  end
end
