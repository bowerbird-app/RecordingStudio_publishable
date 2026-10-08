# frozen_string_literal: true

# Recording Studio 4.2 default layout may still pass `anchor_url` / `back_url`.
# Flatpack PageNav expects `anchor_href` / `secondary_anchor_href`.
module FlatPackPageNavUrlAliases
  def initialize(**kwargs)
    if kwargs[:anchor_href].blank? && kwargs[:anchor_url].present?
      kwargs[:anchor_href] = kwargs[:anchor_url]
    end
    if kwargs[:secondary_anchor_href].blank? && kwargs[:back_url].present?
      kwargs[:secondary_anchor_href] = kwargs[:back_url]
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
