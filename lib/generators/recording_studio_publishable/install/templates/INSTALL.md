RecordingStudioPublishable install complete.

Next steps:

1. Review `config/initializers/recording_studio_publishable.rb` and wire the current actor plus parent-recording authorization.
2. If you use environment-specific settings, create `config/recording_studio_publishable.yml`.
3. The install generator already copied the engine migrations into `db/migrate`.
4. Apply the migrations with `bin/rails db:migrate` on a direct database connection. PgBouncer transaction pooling cannot run the index drop: `disable_ddl_transaction!` splits the work across statements, Rails takes a session advisory lock, and `SET` is session-scoped. Check `pg_stat_activity` for an idle transaction first (`UPGRADING.md`). `DropPublishableChildPerParentIndex` drops `index_rs_publishable_child_per_parent` with `CONCURRENTLY`, including an INVALID copy. Then run `bin/rails generate recording_studio:single_child_index` and migrate. Keep `index_recording_studio_recordings_on_single_child` only. It counts trashed rows. `lock_timeout` and `statement_timeout` are 0 for the drop so an older transaction can finish.
5. Review the generated publishable seed template in `db/seeds.rb`, then replace the example lookup or provide `RECORDING_STUDIO_PUBLISHABLE_PARENT_ID` before running `bin/rails db:seed`.
6. Mount the engine at `/` if you want the default public route `/published/:uuid/:slug`.
7. Enable Publishable on each recordable type with `include RecordingStudio::Capabilities::Publishable.to(**opts)`.
8. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
9. If you want to upload `social_image`, install Active Storage first with `bin/rails active_storage:install` and run `bin/rails db:migrate`. The social form uploads and previews through Attachable, so you can set `config.active_storage.draw_routes = false` once no screen still calls Rails' public blob routes.

Configuration notes:

- Enable Publishable with `include RecordingStudio::Capabilities::Publishable.to(...)`.
- `config.layout` controls the engine layout globally.
- `config.register_public_renderer("Page", controller: "pages", action: :show)` overrides the default `Page -> pages#show` public rendering convention.
- A recordable can opt into a shared cache of its live public show with `publishable_http_cache(request)`. See the README. The hook can read `Current.actor`. A public policy strips `Set-Cookie`. Skip host filters that change the HTML per visitor in the host's own setup.
