# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds")

# Add FlatPack stylesheets to the precompilation list.
Rails.application.config.assets.precompile += %w(flat_pack/flat_pack/content_editor.css flat_pack/flat_pack/variables.css flat_pack/flat_pack/rich_text.css)
