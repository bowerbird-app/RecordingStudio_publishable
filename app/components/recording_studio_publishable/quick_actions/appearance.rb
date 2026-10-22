# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    class Appearance
      TRANSITION_STATES_PARAM_LIMIT = 1024

      def self.from(options)
        new(
          button_class: options.delete(:class),
          menu_class: options.delete(:menu_class),
          states: options.delete(:states),
          html_attributes: options
        )
      end

      def self.options_from_transition_params(params)
        { size: Component.normalize_size(params[:button_size]) }
          .merge(host_style_options(params))
          .merge(identity_options(params))
      end

      def self.host_style_options(params)
        options = {}
        options[:class] = params[:button_class] if params[:button_class].present?
        options[:menu_class] = params[:menu_class] if params[:menu_class].present?
        states = states_from_transition_param(params[:quick_actions_states])
        options[:states] = states if states.present?
        options
      end

      def self.identity_options(params)
        options = {}
        name = Presenter.name_from_param(params[:quick_actions_name])
        options[:name] = name if name.present?
        options[:renderer] = params[:quick_actions_renderer].to_s == "list" ? "list" : "dropdown"
        options
      end

      def self.states_from_transition_param(raw)
        return if raw.blank? || raw.to_s.bytesize > TRANSITION_STATES_PARAM_LIMIT

        parsed = JSON.parse(raw.to_s)
        StateOverrides.normalize(parsed) if parsed.is_a?(Hash)
      rescue JSON::ParserError, ArgumentError
        nil
      end
      private_class_method :states_from_transition_param

      def initialize(button_class:, menu_class:, states:, html_attributes:)
        @host_button_class = button_class
        @host_menu_class = menu_class
        @states = StateOverrides.normalize(states)
        @html_attributes = html_attributes
      end

      attr_reader :html_attributes

      def button_class
        ClassNames.merge(configuration.quick_actions_button_class, @host_button_class).presence
      end

      def menu_class
        ClassNames.merge(configuration.quick_actions_menu_class, @host_menu_class).presence
      end

      def menu_actions(closed_state, schedule_enabled:)
        actions = state_config(closed_state)[:actions]
        schedule_enabled ? actions : actions - [:schedule]
      end

      def state_config(closed_state)
        config = Catalog::CLOSED_STATES.fetch(closed_state).merge(state_override(closed_state))
        validate_style!(config[:style])
        config
      end

      def transition_style_params
        params = {}
        params[:button_class] = @host_button_class if @host_button_class.present?
        params[:menu_class] = @host_menu_class if @host_menu_class.present?
        params[:quick_actions_states] = @states.to_json if @states.present?
        params
      end

      private

      def configuration
        RecordingStudioPublishable.configuration
      end

      def state_override(closed_state)
        configuration.quick_actions_state(closed_state).merge(@states.fetch(closed_state, {}))
      end

      def validate_style!(style)
        return if FlatPack::Button::StyleRegistry.known?(style)

        raise ArgumentError, FlatPack::Button::StyleRegistry.invalid_style_message(style)
      end
    end
  end
end
