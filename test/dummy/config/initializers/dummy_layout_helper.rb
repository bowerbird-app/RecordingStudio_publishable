# frozen_string_literal: true

# Dummy layouts are also used by engine screens, so include the helper on
# ActionView rather than only ApplicationHelper.
Rails.application.config.to_prepare do
  ActionView::Base.include(DummyLayoutHelper)
end
