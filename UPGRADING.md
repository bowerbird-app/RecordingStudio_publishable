# Upgrading

## 0.13.0 — Flatpack 0.1.331 dropdown hooks

Install `recording_studio_publishable` 0.13.0. No migration.

Flatpack must be `0.1.331` or newer. Reload Flatpack CSS and JavaScript. Rebuild host Tailwind so `ms-auto` exists if the host did not already use it.

Quick actions no longer subclass Dropdown. The kit component takes `menu_class:`, `menu_attributes:`, and `with_trigger_label`. The live label is still replaced in place. Publish and unpublish forms keep a surrounding menu open with `data-flat-pack-dropdown-keep-open`.

A host dropdown that copied this gem's old subclass, or that overrode `menu_classes` / `menu_attributes` / `button_attributes`, should call the kit component instead:

```erb
<%= render FlatPack::Button::Dropdown::Component.new(text: "Menu", style: :secondary) do |dropdown| %>
  <% dropdown.menu_item(text: "Rename", icon: "pencil", type: "button") %>
  <% dropdown.menu_html(render(publishable_quick_actions_list_for(page_recording, name: "menu"))) %>
<% end %>
```

Do not put those action-row forms in `menu_form`. That panel is for a field plus submit, and it turns the menu into a dialog.

## 0.12.2 — Housekeeping

Install `recording_studio_publishable` 0.12.2. No migration.

This release drops tracked SimpleCov output, leftover gem-template docs, a nested dummy GitHub workflow, and two stale notes files. Publishable behavior is unchanged.

## 0.12.1 — dummy Flatpack, Root Switchable, and Admin pins

Install `recording_studio_publishable` 0.12.1. No migration.

Development and dummy pin Flatpack `v0.1.329`, Root Switchable `v0.11.0`, dummy Admin `v2.5.1`, Accessible `v0.21.0`, Cache `v0.5.1`, Metrics `v0.6.1`, and Trashable `v0.11.3`. The dummy no longer patches PageNav or Card. Gemspec floors stay as they were (`flat_pack` `>= 0.1.315`).

Hosts still on Root Switchable 0.9.0 or Admin 2.3.0 with Flatpack 0.1.319 or newer should upgrade those gems (Root Switchable 0.11.0, Admin 2.5.1). Do not shim `anchor_url` / `anchor_label` or Card `style:`. Root Switchable 0.10.0 still calls Dropdown `button_attributes`, which Flatpack 0.1.329 removed.

## 0.12.0 — Recording Studio 6.1 layout

Install `recording_studio_publishable` 0.12.0. No migration.

Recording Studio must be `6.1.0` or newer. Flatpack must be `0.1.315` or newer. ViewComponent must be `4.14` or newer and below `5`. Rebuild host Tailwind after the Flatpack bump.

Quick actions use Flatpack 0.1.319's trigger button. On Flatpack 0.1.315 they call `Dropdown#button_attributes` instead. Development pins Flatpack `v0.1.329`.

Current releases of Accessible, Attachable, Cache, Metrics, Root Switchable, Trashable, API, Admin, and Internationalization still require `recording_studio` below 5. Bundler will not install this gem beside those releases. This repository's Gemfiles load `test/support/widen_recording_studio_requirement.rb` before the gemspec so the requirement becomes `>= 6.1.0`. A host that needs one of those gems today has to widen the requirement the same way. That file is not part of the installed gem.

Root Switchable 0.9.0 and Admin 2.3.0 still pass PageNav `anchor_url` / `anchor_label` and Card `style:` that Flatpack 0.1.319 and newer reject. From 0.12.1 the dummy pins Root Switchable 0.11.0 and Admin 2.5.1 instead of patching those constructors.

`config.layout` now defaults to `nil`. A `nil` setting uses `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. `false` renders no layout. A callable is invoked as `call(controller:)`. A blank string, a positional callable, or any other value raises `ArgumentError`.

`recording_studio_publishable/application` is still available, and it is a bare document. It does not draw the page heading, back control, or page nav. Publish screens no longer draw those in the view body. Leave `config.layout` nil to keep them. Set that layout name only when the host renders the heading and nav itself.

Do not hard-code `layout "recording_studio/default_layout"` on a controller. Call `recording_studio_layout` instead. `rake recording_studio:check_layouts` reports those hard-coded calls.

Publish screens set the page title with `content_for :title` and `content_for :subtitle`. Back and close use `flat_pack_page_nav`. The default layout draws one heading. A host view that also renders `FlatPack::PageTitle` for that same heading will show two.

Public pages also set `content_for :document_title` to `publishable_document_title`. That is the SEO title when one is saved, otherwise the parent title. The dummy layout and the bare engine layout use it for `<title>`. Recording Studio's default layout does not. A host layout that replaces the default layout should read `:document_title` for the `<title>` element and `:title` for the visible heading.

`recording_studio_page_nav` is gone. `publishable_hides_page_nav_right?` is how a host layout skips its own right-hand controls on publish, preview, and public screens. The gem no longer fills `:page_nav_right` with a placeholder.

Per-type `public_layout` still wins for the public page and for preview. `nil` uses the same layout chain as the management screens. `false` renders no layout.

## 0.11.0 — collapsed publish rows

Install `recording_studio_publishable` 0.11.0. No migration.

Flatpack must be `0.1.302` or newer. Reload Flatpack CSS and JavaScript. This Flatpack release does not need a Tailwind rebuild.

`ListComponent` is one collapsed line inside a host dropdown. The line shows Draft, the scheduled date, or Published, with that state's icon. Open it for the same rows as before. The separate status line is gone. The dropdown button is unchanged.

Turbo still leaves the outer wrapper in place. The list update redraws the whole collapse, header included. The alert above it still updates on its own.

## 0.10.0 — publish control placements

Install `recording_studio_publishable` 0.10.0. No migration.

Rebuild host Tailwind. This release pins Flatpack `v0.1.296`, and the icon and menu utilities come from that build.

Flatpack 0.1.296 drops Card `style:` (use the default card, or `border:` / `background:` / `shadow:`) and PageNav constructor keywords such as `anchor_href` and `secondary_anchor_href`. PageNav back and close are `with_back` and `with_close`. The dummy layout does that. A host that copied the old constructor call needs the same change.

The publish control no longer replaces its outer node after publish or unpublish. Turbo updates the label and the rows in every quick-actions control for that recording on the page. A host that targeted `#publishable_quick_actions_<id>` with a Turbo Stream replace should stop. The id still marks each wrapper. The stream uses Turbo `targets` and the shared classes `publishable-quick-actions-for-<recording id>` plus `publishable-quick-actions-state`, `publishable-quick-actions-menu-items`, `publishable-quick-actions-alert`, or `publishable-quick-actions-list`. The submitting control's size, name, and state overrides are what the other controls pick up.

Publish and unpublish are PATCH forms. Schedule, Preview, View, SEO, and Social stay links.

This gem does not call `register_page_nav`. To keep the dropdown in the page nav bar, register it from the host layout:

```erb
<% register_page_nav component: publishable_quick_actions_for(page_recording, name: "page-nav", size: :sm), role: :secondary %>
```

Use `ListComponent` (`render_publishable_quick_actions_list`) inside a host dropdown. Pass `name:` when the same page shows more than one control. `name:` is a short slug such as `menu`.

## 0.9.1 — concurrent publishable indexes

Install `recording_studio_publishable` 0.9.1, copy the new migrations, and migrate on a direct database connection:

```bash
bin/rails generate recording_studio_publishable:migrations
bin/rails db:migrate
```

Run `db:migrate` against Postgres itself, or through a pooler in session mode. These migrations cannot run through PgBouncer transaction pooling. `disable_ddl_transaction!` splits each migration into several statements that have to stay on one session. Rails also takes a session-scoped advisory lock for the migrator, and the migration sets `lock_timeout` and `statement_timeout` on that session. Transaction pooling can hand the next statement to a different server connection, which drops the lock and the settings.

### Before you migrate

Concurrent statements set `lock_timeout` and `statement_timeout` to `0`, so they wait until older transactions finish. An `idle in transaction` session holds its snapshot until it commits or rolls back, and the deploy waits with it. Check the oldest open transaction before you migrate:

```sql
SELECT pid, usename, application_name, state, xact_start, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start
LIMIT 1;
```

If `xact_start` is old, or `state` is `idle in transaction`, commit or cancel that session first. Then migrate.

This is safe while the app is serving traffic. The new migrations build or drop indexes with `CONCURRENTLY`, so they do not take a long lock on `recording_studio_recordings` or on the publishables table. Each concurrent statement, including a cleanup `DROP INDEX CONCURRENTLY`, reads `SHOW lock_timeout` and `SHOW statement_timeout`, sets both to `0`, then restores the previous values. A short timeout is not used around those statements. It would also cover the wait inside `CREATE INDEX CONCURRENTLY`, so an older transaction would cancel the build and leave an INVALID unique index.

The migrations generator stamps a 14-digit host version by adding seconds on the clock, starting at the later of the current UTC second and that version. Second 59 rolls into the next minute. A host version that is not a 14-digit clock time, such as `001`, an 8-digit date, minute 60, or a 15-digit stamp, is not parsed as a time and is not cut down to 14 digits. Those copies use integer versions starting at `max(current UTC stamp, highest host version + 1)`, then `+ 1` for each following file.

Copied migrations call `RecordingStudioPublishable::PublishableChildIndex::V1`. That module stays frozen. A later change to this index ships as a new version of the module and a new migration.

### Fresh installs

`20250101000001` still creates the publishables table and its own indexes in a transaction. It no longer creates `index_rs_publishable_child_per_parent`. That unique partial index is created by `AddUniquePublishableChildIndexConcurrently`:

```sql
SHOW lock_timeout;
SHOW statement_timeout;
SET lock_timeout = '0';
SET statement_timeout = '0';
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "index_rs_publishable_child_per_parent"
  ON "recording_studio_recordings" ("parent_recording_id")
  WHERE recordable_type = 'RecordingStudioPublishable::Publishable' AND trashed_at IS NULL;
SET statement_timeout = '<previous>';
SET lock_timeout = '<previous>';
```

The `WHERE` clause omits `trashed_at` when that column is not on `recording_studio_recordings`. An index that already has this name is reused when it is unique, the column is `parent_recording_id`, and the normalized predicate matches.

If that index was built before `trashed_at` existed, its predicate is only `recordable_type = 'RecordingStudioPublishable::Publishable'`. That predicate is stricter: it also covers trashed rows. The migration does not drop it first. It builds `index_rs_publishable_child_per_parent_new` concurrently with the current predicate, checks that the new index is valid, drops the old index concurrently, then renames `_new` to `index_rs_publishable_child_per_parent`. The table has a unique index the whole time. If `_new` comes out INVALID, the migration drops `_new` concurrently and stops. The old index stays.

`_new` is reused only when it is unique, the column is `parent_recording_id`, and the normalized predicate matches. A stray valid index with that name, including a non-unique one, stops the migration. Neither index is dropped or renamed.

If `index_rs_publishable_child_per_parent` is already the correct valid index and a valid `index_rs_publishable_child_per_parent_new` is still beside it, drop the leftover by hand:

```sql
DROP INDEX CONCURRENTLY index_rs_publishable_child_per_parent_new;
```

If the drop is cancelled, the old index can be left INVALID while a matching `_new` is still valid. The error includes the repair steps. Run `bin/rails db:migrate` again. The migration drops that invalid index and renames `_new`.

Any other drifted predicate stops the migration. The message includes the repair steps below.

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
SHOW statement_timeout;
SET lock_timeout = '0';
SET statement_timeout = '0';
DROP INDEX CONCURRENTLY "index_publishables_on_status_and_publish_times";
SET statement_timeout = '<previous>';
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
FROM "public"."recording_studio_recordings"
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
