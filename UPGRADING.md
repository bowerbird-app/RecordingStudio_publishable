# Upgrading

## 0.9.1 — concurrent publishable indexes

Install `recording_studio_publishable` 0.9.1, copy the new migrations, and migrate:

```bash
bin/rails generate recording_studio_publishable:migrations
bin/rails db:migrate
```

This is safe while the app is serving traffic. The new migrations build or drop indexes with `CONCURRENTLY`, so they do not take a long lock on `recording_studio_recordings` or on the publishables table. Each one reads `SHOW lock_timeout`, sets it to `5s` only for the short lock at the start and end of that concurrent statement, then restores the previous value.

### Fresh installs

`20250101000001` still creates the publishables table and its own indexes in a transaction. It no longer creates `index_rs_publishable_child_per_parent`. That unique partial index is created by `AddUniquePublishableChildIndexConcurrently`:

```sql
SHOW lock_timeout;
SET lock_timeout = '5s';
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "index_rs_publishable_child_per_parent"
  ON "recording_studio_recordings" ("parent_recording_id")
  WHERE recordable_type = 'RecordingStudioPublishable::Publishable' AND trashed_at IS NULL;
SET lock_timeout = '<previous>';
```

The `WHERE` clause omits `trashed_at` when that column is not on `recording_studio_recordings`.

`20260516000100` does not create `index_publishables_on_status_and_publish_times` when `index_rs_publishables_on_state_window` (or any equivalent index on `status`, `publish_at`, `unpublish_at`) is already there. Fresh installs keep that one index.

If nothing equivalent exists, `20260516000100` still runs:

```sql
CREATE INDEX IF NOT EXISTS "index_publishables_on_status_and_publish_times"
  ON "recording_studio_publishable_publishables" ("status", "publish_at", "unpublish_at");
```

### Hosts that already ran the old migrations

Leave the already-migrated files in place. The generator only copies the new migrations. `db:migrate` then:

- Skips the unique index when `index_rs_publishable_child_per_parent` already exists and is valid.
- Drops `index_publishables_on_status_and_publish_times` only when `index_rs_publishables_on_state_window` exists, covers the same columns, and `pg_index.indisvalid` is true:

```sql
SHOW lock_timeout;
SET lock_timeout = '5s';
DROP INDEX CONCURRENTLY "index_publishables_on_status_and_publish_times";
SET lock_timeout = '<previous>';
```

`index_rs_publishables_on_state_window` is not dropped. If the duplicate is already gone, the migration does nothing.

Rolling this migration back raises `ActiveRecord::IrreversibleMigration`. Recreating the duplicate would put a second identical index on a live table.

### Invalid unique index

A failed `CREATE INDEX CONCURRENTLY` leaves `index_rs_publishable_child_per_parent` behind with `pg_index.indisvalid = false`. The migration will not drop a unique index, and `IF NOT EXISTS` would skip a rebuild. It stops with instructions. Rebuild it yourself, then run `db:migrate` again:

```sql
SET lock_timeout = '5s';
DROP INDEX CONCURRENTLY index_rs_publishable_child_per_parent;
```

The migration then runs `CREATE UNIQUE INDEX CONCURRENTLY` as shown above. If `trashed_at` is absent, drop `AND trashed_at IS NULL` from the `WHERE` clause.

### Copied migrations that have not run yet

The generator will not overwrite a migration you already copied. If `create_recording_studio_publishable_publishables` or `add_indexes_to_publishable` is in the host app and has not been migrated, replace those files with the current gem copies (keep the host timestamp) before `db:migrate`. Otherwise the old copies still build the unique index inside a transaction and still add the duplicate status index.
