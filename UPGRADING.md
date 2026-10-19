# Upgrading

## 0.9.1 — concurrent publishable indexes

Install `recording_studio_publishable` 0.9.1, copy the new migrations, and migrate on a direct database connection:

```bash
bin/rails generate recording_studio_publishable:migrations
bin/rails db:migrate
```

Run `db:migrate` against Postgres itself, or through a pooler in session mode. These migrations cannot run through PgBouncer transaction pooling. `disable_ddl_transaction!` splits each migration into several statements that have to stay on one session. Rails also takes a session-scoped advisory lock for the migrator, and the migration sets `lock_timeout` on that session. Transaction pooling can hand the next statement to a different server connection, which drops the lock and the setting.

This is safe while the app is serving traffic. The new migrations build or drop indexes with `CONCURRENTLY`, so they do not take a long lock on `recording_studio_recordings` or on the publishables table. Each concurrent statement reads `SHOW lock_timeout`, sets it to `0` (wait until older transactions finish), then restores the previous value. A 5 second timeout is not used. That timeout also covers the wait inside `CREATE INDEX CONCURRENTLY`, so an older transaction cancels the build and leaves an INVALID unique index.

The migrations generator stamps each copied file at `max(current UTC second, highest host migration version) + 1, + 2, ...` in gem filename order. Copies stay unique even when several are written in the same second.

### Fresh installs

`20250101000001` still creates the publishables table and its own indexes in a transaction. It no longer creates `index_rs_publishable_child_per_parent`. That unique partial index is created by `AddUniquePublishableChildIndexConcurrently`:

```sql
SHOW lock_timeout;
SET lock_timeout = '0';
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "index_rs_publishable_child_per_parent"
  ON "recording_studio_recordings" ("parent_recording_id")
  WHERE recordable_type = 'RecordingStudioPublishable::Publishable' AND trashed_at IS NULL;
SET lock_timeout = '<previous>';
```

The `WHERE` clause omits `trashed_at` when that column is not on `recording_studio_recordings`. An index that already has this name is reused only when it is unique, the column is `parent_recording_id`, and the normalized predicate matches. A drifted predicate (for example an older one that does not mention `trashed_at`) stops the migration. The message includes the repair steps below.

`20260516000100` does not create `index_publishables_on_status_and_publish_times` when a valid plain btree index on `status`, `publish_at`, `unpublish_at` is already there (`index_rs_publishables_on_state_window` on a fresh install). The existing index has to be non-unique, with no `WHERE`, no opclass, no sort order, and no `INCLUDE`. Expression indexes are not treated as that index. Fresh installs keep the one state-window index.

If nothing equivalent exists, `20260516000100` still runs:

```sql
CREATE INDEX IF NOT EXISTS "index_publishables_on_status_and_publish_times"
  ON "recording_studio_publishable_publishables" ("status", "publish_at", "unpublish_at");
```

### Hosts that already ran the old migrations

Leave the already-migrated files in place. The generator only copies the new migrations. `db:migrate` then:

- Skips the unique index when `index_rs_publishable_child_per_parent` already exists, is valid, and matches the column and predicate above.
- Drops `index_publishables_on_status_and_publish_times` only when `index_rs_publishables_on_state_window` exists, is that same plain btree index, and is valid:

```sql
SHOW lock_timeout;
SET lock_timeout = '0';
DROP INDEX CONCURRENTLY "index_publishables_on_status_and_publish_times";
SET lock_timeout = '<previous>';
```

`index_rs_publishables_on_state_window` is not dropped. If the duplicate is already gone, the migration does nothing.

Rolling this migration back raises `ActiveRecord::IrreversibleMigration`. Recreating the duplicate would put a second identical index on a live table.

### Invalid unique index

`CREATE INDEX CONCURRENTLY` can be cancelled while it waits for an older transaction. Postgres leaves `index_rs_publishable_child_per_parent` behind with `pg_index.indisvalid = false`, and `IF NOT EXISTS` would then skip a rebuild.

If this run created that invalid index, the migration drops it with `DROP INDEX CONCURRENTLY` and stops. Nothing invalid is left behind. Fix the cause (often rows that collide, or a session that was cancelled) and run `bin/rails db:migrate` again.

An INVALID unique index that was already there is not dropped. A unique index with the right name and a different predicate is not dropped either. The migration stops and prints repair steps:

```sql
SELECT parent_recording_id, count(*)
FROM recording_studio_recordings
WHERE recordable_type = 'RecordingStudioPublishable::Publishable' AND trashed_at IS NULL
GROUP BY parent_recording_id
HAVING count(*) > 1;
```

That `WHERE` clause is the one the migration would build. It omits `trashed_at` when the column is not on the table. When the query returns no rows:

```sql
DROP INDEX CONCURRENTLY "public"."index_rs_publishable_child_per_parent";
```

Use the schema-qualified name from the message if the index is not in `public`. Then:

```bash
bin/rails db:migrate
```

The migration runs `CREATE UNIQUE INDEX CONCURRENTLY` as shown above.

### Copied migrations that have not run yet

The generator will not overwrite a migration you already copied. If `create_recording_studio_publishable_publishables` or `add_indexes_to_publishable` is in the host app and has not been migrated, replace those files with the current gem copies (keep the host timestamp) before `db:migrate`. Otherwise the old copies still build the unique index inside a transaction and still add the duplicate status index.
