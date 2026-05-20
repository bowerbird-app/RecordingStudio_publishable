# frozen_string_literal: true

require_relative "hooks"

module RecordingStudioPublishable
  class Configuration
    DEFAULT_PUBLIC_PATH = "/published/:uuid/:slug"
    PublicRenderer = Struct.new(:controller, :action, :layout, keyword_init: true) do
      def template_path
        controller_path = controller.to_s.underscore
        action_name = action.presence || :show
        "#{controller_path}/#{action_name}"
      end
    end

    attr_accessor :current_actor_resolver,
                  :management_authorizer,
                  :default_time_zone,
                  :layout,
                  :canonical_redirect_status
    attr_reader :hooks, :public_path_configs, :public_renderer_configs

    def initialize
      @current_actor_resolver = method(:default_current_actor_resolver)
      @management_authorizer = method(:default_management_authorizer)
      @default_time_zone = default_rails_time_zone
      @layout = "recording_studio_publishable/application"
      @canonical_redirect_status = :found
      @public_path_configs = {}
      @public_renderer_configs = {}
      @hooks = Hooks.new
    end

    def to_h
      {
        default_time_zone: default_time_zone,
        layout: layout,
        canonical_redirect_status: canonical_redirect_status,
        public_path_configs: public_path_configs.dup,
        public_renderer_configs: public_renderer_configs.transform_values(&:to_h),
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

    def register_public_renderer(recordable_type, controller: nil, action: nil, layout: nil)
      normalized_type = normalize_recordable_type(recordable_type)
      default_renderer = default_public_renderer_for(normalized_type)

      public_renderer_configs[normalized_type] = PublicRenderer.new(
        controller: controller.presence || default_renderer.controller,
        action: action.presence || default_renderer.action,
        layout: layout
      )
    end

    def public_renderer_for(recordable_type)
      normalized_type = normalize_recordable_type(recordable_type)
      public_renderer_configs[normalized_type] || default_public_renderer_for(normalized_type)
    end

    def public_controller_for(recordable_type)
      public_renderer_for(recordable_type).controller
    end

    def public_action_for(recordable_type)
      public_renderer_for(recordable_type).action || :show
    end

    def public_layout_for(recordable_type)
      public_renderer_for(recordable_type).layout
    end

    def default_layout
      layout
    end

    def default_layout=(value)
      self.layout = value
    end

    def public_template_for(recordable_type)
      public_renderer_for(recordable_type).template_path
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
      recording_studio_actor = resolve_recording_studio_actor
      return recording_studio_actor if recording_studio_actor.present?
      return unless controller.respond_to?(:current_user, true)

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
      return time_zone_from_active_support if time_zone_from_active_support.present?
      return time_zone_from_rails_config if time_zone_from_rails_config.present?

      "UTC"
    rescue StandardError
      "UTC"
    end

    def time_zone_from_active_support
      return unless Time.respond_to?(:zone) && Time.zone.respond_to?(:name)

      Time.zone.name
    end

    def time_zone_from_rails_config
      return unless defined?(Rails)

      config = Rails.application&.config
      return unless config.respond_to?(:time_zone)

      config.time_zone
    end

    def normalize_recordable_type(recordable_type)
      recordable_type.is_a?(Class) ? recordable_type.name : recordable_type.to_s
    end

    def default_public_renderer_for(recordable_type)
      demodulized = normalize_recordable_type(recordable_type).demodulize
      sanitized = demodulized.to_s.gsub(/[^A-Za-z0-9_]/, "")

      PublicRenderer.new(
        controller: sanitized.underscore.pluralize,
        action: :show,
        layout: nil
      )
    end

    def resolve_callable(callable, **kwargs)
      return unless callable

      parameters = callable.parameters
      return callable.call(**kwargs) if parameters.any? { |type, _| type == :keyrest }

      supported = parameters.filter_map { |type, name| name if %i[key keyreq].include?(type) }
      callable.call(**kwargs.slice(*supported))
    end

    def resolve_recording_studio_actor
      return unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:configuration)

      actor_resolver = RecordingStudio.configuration.respond_to?(:actor) ? RecordingStudio.configuration.actor : nil
      return actor_resolver unless actor_resolver.respond_to?(:call)

      actor_resolver.call
    rescue StandardError
      nil
    end
  end
end
