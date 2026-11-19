# frozen_string_literal: true

module FlatpackIconAssertions
  def rendered_icon_markup(name, variant: :outline)
    raw = name.to_s.strip.tr("_", "-")
    mapped = FlatPack::Shared::IconComponent::NAME_MAP.fetch(raw, raw)
    markup = FlatPack::Heroicons.fetch(variant, mapped)
    flunk "Flatpack has no #{variant} icon #{name}" if markup.blank?

    expand_svg_void_tags(markup)
  end

  def assert_rendered_icon(html, name, variant: :outline)
    assert_includes expand_svg_void_tags(html), rendered_icon_markup(name, variant: variant),
                    "expected a rendered #{variant} #{name} svg"
  end

  def rendered_icon_node(scope, name, variant: :outline)
    markup = rendered_icon_markup(name, variant: variant)
    node = icon_scope(scope).css("svg").find { |svg| expand_svg_void_tags(svg.inner_html).include?(markup) }
    assert node, "expected a rendered #{variant} #{name} svg"
    node
  end

  private

  def icon_scope(scope)
    return scope if scope.respond_to?(:css)

    Nokogiri::HTML(scope.to_s)
  end

  def expand_svg_void_tags(html)
    html.to_s.gsub(%r{<([A-Za-z][\w:.-]*)([^<>]*?)\s*/>}, '<\1\2></\1>')
  end
end
