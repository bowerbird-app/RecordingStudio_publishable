RecordingStudioPublishable install complete.

Next steps:

1. Review `config/initializers/recording_studio_publishable.rb` and wire the current actor plus parent-recording authorization.
2. If you use environment-specific settings, create `config/recording_studio_publishable.yml`.
3. The install generator already copied the engine migrations into `db/migrate`.
4. Apply the migrations with `bin/rails db:migrate` on a direct database connection. PgBouncer transaction pooling cannot run them: `disable_ddl_transaction!` splits the work across statements, Rails takes a session advisory lock, and `SET` is session-scoped. Check `pg_stat_activity` for an idle transaction first (`UPGRADING.md`). Index changes use `CONCURRENTLY` and are safe on a live recordings table. `lock_timeout` and `statement_timeout` are 0 for those statements so an older transaction can finish. If this run leaves `index_rs_publishable_child_per_parent` INVALID, the migration drops that invalid index and stops. An INVALID unique index left by an earlier attempt is not dropped for you. Rebuild steps are in `UPGRADING.md`.
5. Review the generated publishable seed template in `db/seeds.rb`, then replace the example lookup or provide `RECORDING_STUDIO_PUBLISHABLE_PARENT_ID` before running `bin/rails db:seed`.
6. Mount the engine at `/` if you want the default public route `/published/:uuid/:slug`.
7. Enable Publishable on each recordable type with `include RecordingStudio::Capabilities::Publishable.to(**opts)`.
8. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
9. If you want to upload `social_image`, install Active Storage first with `bin/rails active_storage:install` and run `bin/rails db:migrate`.

Configuration notes:

- Enable Publishable with `include RecordingStudio::Capabilities::Publishable.to(...)`.
- `config.layout` controls the engine layout globally.
- `config.register_public_renderer("Page", controller: "pages", action: :show)` overrides the default `Page -> pages#show` public rendering convention.
