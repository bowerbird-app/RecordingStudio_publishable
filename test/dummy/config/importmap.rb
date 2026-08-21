# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Pin FlatPack controllers. preload: false matches gem_template so Stimulus lazy-loads them.
pin_all_from FlatPack::Engine.root.join("app/javascript/flat_pack/controllers"), under: "controllers/flat_pack", to: "flat_pack/controllers", preload: false
pin "flat_pack/heroicons", to: "flat_pack/heroicons.js", preload: false
pin "flat_pack/tiptap/addon_registry", to: "flat_pack/tiptap/addon_registry.js", preload: false

pin "@rails/activestorage", to: "activestorage.esm.js"
recording_studio_attachable_spec = Bundler.load.specs.find { |spec| spec.name == "recording_studio_attachable" }
recording_studio_attachable_spec ||= Gem.loaded_specs["recording_studio_attachable"]
recording_studio_attachable_spec ||= Gem::Specification.find_all_by_name("recording_studio_attachable").max_by(&:version)

if recording_studio_attachable_spec.present?
  recording_studio_attachable_path = recording_studio_attachable_spec.full_gem_path
  pin_all_from File.join(recording_studio_attachable_path, "app/javascript/controllers/recording_studio_attachable"),
    under: "controllers/recording_studio_attachable",
    to: "controllers/recording_studio_attachable",
    preload: false
  pin "recording_studio_attachable/tiptap/attachment_image_addon",
    to: "recording_studio_attachable/tiptap/attachment_image_addon.js",
    preload: false
end
