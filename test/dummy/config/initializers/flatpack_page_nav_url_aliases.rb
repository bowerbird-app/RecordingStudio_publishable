# frozen_string_literal: true

# Recording Studio 4.2 default layout passes `anchor_url` / `back_url`.
# Flatpack 0.1.133 PageNav understands `anchor_href` and always uses Stimulus
# history.back for the back control. Map the layout close URL so one PageNav
# is enough — do not render a second PageNav in addon views.
module FlatPackPageNavUrlAliases
  def initialize(**kwargs)
    if kwargs[:anchor_href].blank? && kwargs[:anchor_url].present?
      kwargs[:anchor_href] = kwargs[:anchor_url]
    end
    kwargs.delete(:anchor_url)
    kwargs.delete(:back_url)
    super(**kwargs)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(FlatPack::PageNav::Component)
  next if FlatPack::PageNav::Component.ancestors.include?(FlatPackPageNavUrlAliases)

  FlatPack::PageNav::Component.prepend(FlatPackPageNavUrlAliases)
end
