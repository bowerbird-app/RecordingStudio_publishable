RecordingStudioPublishable install complete.

Next steps:

1. Review `config/initializers/recording_studio_publishable.rb` and wire the current actor plus parent-recording authorization.
2. If you use environment-specific settings, create `config/recording_studio_publishable.yml`.
3. The install generator already copied the engine migrations into `db/migrate`.
4. Apply the migrations with `bin/rails db:migrate`.
5. Review the generated publishable seed template in `db/seeds.rb`, then replace the example lookup or provide `RECORDING_STUDIO_PUBLISHABLE_PARENT_ID` before running `bin/rails db:seed`.
6. Mount the engine at `/` if you want the default public route `/published/:uuid/:slug`.
7. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
8. If you want to upload `social_image`, install Active Storage first with `bin/rails active_storage:install` and run `bin/rails db:migrate`.

Configuration notes:

- `config.default_layout` controls the engine layout globally.
- `config.edit_layout` lets you override only the edit publishable screen layout.
- `config.register_public_renderer("Page", controller: "pages", action: :show)` overrides the default `Page -> pages#show` public rendering convention.
