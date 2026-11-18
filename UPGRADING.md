# Upgrading

## 1.3.1 — Controller modulepreload follows the application entry

Install `recording_studio_publishable` 1.3.1. No migration.

`config/importmap.rb` pins `publishable_share_controller` and `publishable_quick_actions_controller` with `preload: "application"`. The `application` entry still modulepreloads both controllers. Another entry, such as `landing`, keeps both pins in the import map and does not modulepreload them. importmap-rails 2.2.2, the version in the dummy lockfile, accepts that preload value. The gemspec does not gain an `importmap-rails` dependency.

## 1.3.0 — Public link on the publish snapshot

Install `recording_studio_publishable` 1.3.0. No migration.

`publish`, `unpublish`, and `update_publishable` add `public_path` and `public_url` to the 200 body. Both are empty unless the recording is live. `public_url` is an absolute URL when `Rails.application.routes.default_url_options` has a host, and empty when that host is missing.

```ruby
Rails.application.routes.default_url_options = { host: "press.example.com", protocol: "https" }
```

Mailer `default_url_options` is a separate setting. Show and list payloads can call `recording.publishable_public_read` for `status`, `slug`, `publish_at`, `unpublish_at`, `public_path`, and `public_url`.

## 1.2.1 — Publish MCP copy

Install `recording_studio_publishable` 1.2.1. No migration. `publish`, `unpublish`, and `update_publishable` OpenAPI summaries, descriptions, and `update_publishable` field wording changed. Action names and fields did not.

## 1.2.0 — Public HTTP cache

Install `recording_studio_publishable` 1.2.0. No migration.

The public show stays private until a recordable opts in. Define `publishable_http_cache(request)` and return `RecordingStudioPublishable::HttpCachePolicy`. Return nil, or leave the method off, and the response is `Cache-Control: private, no-store` with no strong ETag from this gem.

The gem loads the session and sets `Current.actor` from the signed-in user when that attribute is still blank, then calls the hook. The hook can read `Current.actor`. Return nil for a signed-in viewer who should not share the public copy.

```ruby
def publishable_http_cache(_request)
  RecordingStudioPublishable::HttpCachePolicy.new(
    public: true,
    max_age: 300,
    stale_while_revalidate: 60,
    etag: "#{id}:#{updated_at.to_i}"
  )
end
```

`vary` defaults to `Accept-Encoding`. The gem calls the method only after it has a live publishable. Draft, scheduled, unpublished, missing, and preview requests do not call it and send `Cache-Control: private, no-store`. Preview is never cached.

On a public policy the response is `Cache-Control: public, max-age=300, stale-while-revalidate=60` (the last directive is omitted when `stale_while_revalidate` is nil), `Vary`, and a strong `ETag`. The etag is a digest of the policy `etag` plus the publishable id, status, slug, `publish_at`, `unpublish_at`, and `updated_at`. Unpublish, republish, and an edit that changes `updated_at` change the digest. Put the recordable's own version in `etag` when the page body changes without a publishable write. A matching `If-None-Match` returns 304 before the inner controller runs. The gem skips the session write and strips `Set-Cookie`.

The public layout has to stop emitting per-request tokens when the policy is public. Call `publishable_document_security_tags` instead of `csrf_meta_tags` and `csp_meta_tag`. It emits both tags on every other response. A public policy also drops a nonce-based `Content-Security-Policy` header and clears the nonce. A policy that does not use a nonce stays.

Host filters that set cookies are stripped on a public cached page. Skip those filters in the host's own setup when they also change the HTML. Stripping the cookie does not undo a render that already varied by visitor.

The share sheet id is `publishable-share-` plus the publishable recording id, or the parent recording id when that child is missing. It is stable across requests. Hosts that rewrote a random id can delete that rewrite.

## 1.1.0 — Recording Studio API 1.1

Install `recording_studio_publishable` 1.1.0. Bump `recording_studio_api` to `1.1.0` or newer, below 2. Bump `recording_studio` to `7.1.0` or newer, below 8. No Publishable migration.

Attachable `v0.30.0` still requires API `< 1.0`. A host that installs both needs an Attachable release that allows API `>= 1.1`, `< 2.0`. That release also requires Flatpack `>= 0.1.376`.

API 1.0 removed `RecordingStudioApi::Hooks` and `RecordingStudioApi::Services::BaseService`. Publishable does not call them. Register service hooks on `RecordingStudio.configuration.hooks`.

API 0.26 resolves a member action id through the grant's accessible recordings before the handler runs. A trashed, foreign, or wrong-type id returns 404. Publishable's handlers still use `context.recording` and write as `access_grant.actor`.

Registration rejects unknown keywords. Publishable passes `capability`, `version`, `version_notes`, `http_verb`, `scope`, `required_role`, `handler`, `serializer`, `input_contract`, `openapi`, `openapi_for`, and `api`. Those keywords are accepted. Publishable does not declare `trashed_semantics`.

Delete a copied API 0.5.6 `RecordingStudio::Access.roles` shim. API 1.1 does not read it.

A host that copied `app/views/recording_studio_publishable/publishables/social.html.erb` should pass `picker_url: recording_studio_attachable.recording_attachment_picker_path(publishable_recording)` into the attachment image picker modal. Attachable uses that local as the search endpoint.

## 1.0.0 — Core service hooks

Install `recording_studio_publishable` 1.0.0. No migration. There is no alias and no compatibility shim.

`RecordingStudioPublishable::Hooks`, `RecordingStudioPublishable::Services::BaseService`, and `RecordingStudioPublishable.configuration.hooks` are gone. `configuration.to_h` no longer includes `:hooks_registered`.

`Update`, `Transition`, `EnsureChild`, and `Resolve` inherit `RecordingStudio::Services::BaseService`. Register `before_service`, `after_service`, and `around_service` on `RecordingStudio.configuration.hooks`. Core runs those hooks for every service from every gem. Check the service class before you act.

`before_service` receives the service class and the service arguments. `after_service` receives the service class and the result. `around_service` receives the service instance and the block that runs the service. Call that block, unless you are returning a result yourself.

`RecordingStudioPublishable.subscribe` and the `published.recording_studio_publishable` notifications are unchanged.

The engine no longer runs `:before_initialize`, `:on_configuration`, or `:after_initialize`. Nothing in the org listened for those events.

### Terms and conditions

Move these registrations from `RecordingStudioPublishable.configuration.hooks` to `RecordingStudio.configuration.hooks`.

- `SoleLive` registers `after_service` and a latch on `:recording_studio_terms_sole_live`. Keep the `Update` check. Move `hooks.on` and `hooks.registered?` for that latch to Core.
- `OutlinePublish` registers `around_service` and a latch on `:recording_studio_terms_outline_publish`. The hook already limits itself to `Update`. Move the latch the same way. Keep calling the block for every other service.
- `Published` uses the latch `:recording_studio_terms_published` to decide `installed?`. Move that latch to Core. Leave `RecordingStudioPublishable.subscribe(:published)` where it is.

### Broadcasts

Move the `after_service` block in `subscribe_publishable_writes!` to Core. Ignore service classes other than Publishable's. `SentPublishableLock` registers `around_service` and already limits the refusal to `Update` and `Transition`. Move that registration to Core and keep calling the block for every other service.

## 0.19.0 — SQL scopes for published and indexable lists

Install `recording_studio_publishable` 0.19.0. No migration. No new column.

`Page.published`, `Page.indexable`, and the other publish scopes run in SQL. `Page.indexable.limit(12)` and `Page.indexable.count` do not load every row. `Recording.currently_published` is the same kind of scope for recordings. Chain it.

The publish window is still `Publishable.currently_published`. A record is inside the window when status is published, `publish_at` is blank or at or before the current time, and `unpublish_at` is blank or after the current time. `publish_at` equal to now counts. `unpublish_at` equal to now does not.

Recordable scopes use the newest kept parent recording and that parent's kept publishable child. Kept means every registered recording filter passes. Trashable's filter is the usual one. An older parent recording does not put the recordable on the list. `Recording.currently_published` looks at that recording's own kept child, and the recording must be kept.

`indexable` also drops a robots value that contains `noindex`, including `noindexable`, and a canonical URL that is not a path or an http or https URL with a host. `http://` is not indexable. A blank canonical stays in `indexable`. The scope does not ask whether the public URL resolves. Call `indexable?` or `indexable_url` on the rows you render.

These scopes do not grant access. Accessible still decides who can read a root.

Nothing new becomes public. These rows drop out of the lists they used to match:

- A recordable with a trashed parent drops out of `published` and the other publish scopes. `indexable` already required a kept parent.
- A recordable drops out of a scope when only an older parent matches. The newest kept parent has to match.
- `http://`, `https://`, and `http:///path` drop out of `indexable`.
- A robots value that merely contains `noindex` stays out of `indexable`, and `indexable_url` now returns nil for it.
- A trashed recording is not `currently_published?`. `indexable?` on a recording is true only when that recording is the newest kept parent of an indexable recordable.

State changes still go through the publish services.

## 0.18.1 — Recording Studio API 0.24

Install `recording_studio_publishable` 0.18.1. Recording Studio API must be `0.24.0` or newer, below 1. Flatpack must be `0.1.341` or newer. No migration.

API 0.24 also requires Accessible `>= 0.44.0`, `< 1.0`, Logs `>= 0.8.0`, `< 1.0`, Metrics `>= 0.9.0`, `< 1.0`, Moveable `>= 5.0`, `< 6.0`, and Trashable `>= 0.17.0`, `< 1.0`. Publishable does not depend on those gems. Hosts that install API need them. Development and the dummy pin API `v0.24.0`, Moveable `v5.0.0`, Trashable `v0.17.0`, Accessible `v0.44.0`, Logs `v0.8.0`, and Metrics `v0.9.0`, on Recording Studio `v7.0.0`. The dummy no longer defines `Recording.recording_studio_trashable_kept_sql`. API 0.24 and Admin 2.16 call `Recording.kept` and `RecordingStudio.kept_sql`.

## 0.18.0 — Recording Studio 7 and one publishable child per parent

Install `recording_studio_publishable` 0.18.0 and Recording Studio `7.0.0` or newer, below 8. `root_recording_for` only finds a root. It returns `nil` and does not write. Create a root with `RecordingStudio.create_root_recording!`.

`RecordingStudioPublishable::Publishable` declares `one_per_parent: true`. One publishable recording is allowed directly under a parent. A second create raises `RecordingStudio::SlotTaken`, including when the existing child is trashed. Trashing a publishable does not free the slot. Revise the existing child, or remove that recording, before creating another. `EnsureChild` returns the kept child when a concurrent create loses the slot. When the only child is trashed, `EnsureChild` fails with `SlotTaken` and does not insert a replacement.

Lookup stays on `root_recording_for` and handles `nil`. Seeds and setup that used to create a root by looking it up pass an actor:

```ruby
root = RecordingStudio.create_root_recording!(workspace, actor: Current.actor)
```

A second call returns the same root and does not append another event.

### Migration

Copy the engine migrations, drop the old index, then generate core's index. Run `db:migrate` on a direct database connection. PgBouncer transaction pooling cannot run the drop: `disable_ddl_transaction!` splits the work across statements, Rails holds a session advisory lock, and `SET lock_timeout` and `SET statement_timeout` have to stay on that session. Check `pg_stat_activity` for an idle transaction first. The drop sets both timeouts to `0` so it waits for that transaction.

```bash
bin/rails generate recording_studio_publishable:migrations
bin/rails generate recording_studio:single_child_index
bin/rails db:migrate
```

`DropPublishableChildPerParentIndex` drops `index_rs_publishable_child_per_parent` with `CONCURRENTLY` when that index is present, including when it is `INVALID`. It does not recreate it. Core's generator writes the replacement. For an app whose only single-child type is Publishable, that migration is:

```ruby
class AddRecordingStudioSingleChildIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :recording_studio_recordings,
              %i[parent_recording_id recordable_type],
              unique: true,
              name: "index_recording_studio_recordings_on_single_child",
              where: "recordable_type IN ('RecordingStudioPublishable::Publishable')",
              if_not_exists: true
  end
end
```

Run the generator in the host app. The `IN` list is every child type that is single under every parent when the generator runs, not only Publishable. Do not keep `index_rs_publishable_child_per_parent` beside `index_recording_studio_recordings_on_single_child`.

The old index ignored trashed rows. Core's index counts them. Before migrating, find parents that already have more than one publishable recording, trashed or not:

```sql
SELECT parent_recording_id, count(*)
FROM recording_studio_recordings
WHERE recordable_type = 'RecordingStudioPublishable::Publishable'
GROUP BY parent_recording_id
HAVING count(*) > 1;
```

Leave one recording under each of those parents. The new index will not build while a duplicate remains.

## 0.17.0 — Social images use Attachable upload routes

Install `recording_studio_publishable` 0.17.0. No migration. Keep Active Storage installed so attachment bytes have a place to live. Publishable still does not depend on Attachable in the gemspec; the host that shows the social form already mounts Attachable.

The social image picker posts direct uploads to Attachable's recording direct-upload route. That route authorizes `:upload` and calls `DirectUpload.prepare!`. The preview image loads through `attachment_preview_file_path` with the `social_share` variant. The form does not call `rails_direct_uploads_path` or `rails_blob_path`.

A host that copied `app/views/recording_studio_publishable/publishables/social.html.erb` should make the same two swaps. A host that copied Attachable's upload page should use `recording_direct_uploads_path(recording)` the way Attachable's uploader does.

When nothing in the host still needs Rails' public blob routes, set:

```ruby
config.active_storage.draw_routes = false
```

## 0.16.0 — Kept recordings

Install `recording_studio_publishable` 0.16.0 and Recording Studio `6.14.0` or newer. No migration.

Publish queries call `RecordingStudio::Recording.kept` and `RecordingStudio.kept_sql`. `RecordingStudioPublishable::TrashedAt` is gone. Publishable does not check for a `trashed_at` column and does not write its own `trashed_at IS NULL` SQL.

Core registers no filters, so `kept` matches every recording until an addon registers one. Trashable `0.16.0` registers that filter. Publishable does not depend on Trashable, so the gemspec does not require it. Development and the dummy pin Trashable `v0.16.0` and Accessible `v0.42.0`.

The unique publishable-child index is unchanged. `PublishableChildIndex::V1` still adds `trashed_at IS NULL` to that index only when the column is already on `recording_studio_recordings`.

## 0.15.0 — Publishable OpenAPI overrides and transition no-ops

Install `recording_studio_publishable` 0.15.0 and Recording Studio API `~> 0.23`. No migration.

`publish` on a recording that is already live returns the existing child and does not restamp `publish_at` or clear `unpublish_at`. `unpublish` on a recording that is already draft and not scheduled does not write, does not bump `updated_at`, and does not create a publishable child. A scheduled recording still unpublished to draft with both times cleared. `update_publishable` is unchanged: an empty or identical payload still saves.

Hosts can override OpenAPI title and description for one type:

```ruby
RecordingStudioPublishable::Api.override_openapi(
  type: "PressKit",
  action: :publish,
  title: "Press Kit - Publish",
  description: "Publishes this press kit so visitors can see the live page."
)
```

`Api.openapi_for(action: :publish, type: "PressKit")` returns that type's document. Other types keep the generic Publishable strings. The 200 response stays `PublishableSnapshot`. Recording Studio API `~> 0.23` merges that overlay into OpenAPI and the MCP catalog.

## 0.14.0 — Public share button

Install `recording_studio_publishable` 0.14.0. No migration.

`publishable_share_button(recording)` is available in every view. It renders a Flatpack copy button only while `recording.currently_published?` is true, and only when an absolute public URL can be built. The copied value is that public page URL. It is not the current request URL, an embed URL, or a preview URL.

```erb
<%= publishable_share_button(recording) %>
<%= publishable_share_button(recording, icon_only: false, style: :primary, label: "Copy link") %>
<%= publishable_share_button(recording, mode: :modal) %>
```

`mode: :copy` is the default and copies the public URL directly. `mode: :modal` opens a sheet. The sheet preview uses social title, then SEO title, then the recordable title, and social description, then SEO description. Its links are the same absolute public URL. `destinations` narrows or reorders `copy`, `native`, `linkedin`, `x`, `facebook`, and `email`. Style, icon, and label overrides still apply to the trigger in both modes.

A host that copied presskits' private share button should delete that copy and call this helper. The presskits fallback to the current request URL is not part of this button.

App-wide defaults:

```ruby
RecordingStudioPublishable.configure do |config|
  config.share_button = { style: :primary, icon: "link", icon_only: false, mode: :modal }
end
```

Per-call arguments win over `config.share_button`. Built-in defaults are icon-only, secondary, md, icon `arrow-up-tray`, label `recording_studio.publishable.share.label` ("Share"). The success text after a copy is Flatpack's clipboard copy.

## 0.13.3 — API publish writes as the grant actor

Install `recording_studio_publishable` 0.13.3. No migration.

`publish`, `unpublish`, and `update_publishable` pass `context.access_grant.actor` into the same Update/Transition services the UI uses. Host `authorize_write` hooks that call Accessible on that actor see the grant subject, not the API client. A denied write still raises `InvalidActionInputError`, the same as other service failures. Invalid publishable fields still raise `InvalidActionInputError`. Recording Studio API rejects a `client_credentials` token whose grant has no actor before the handler runs.

## 0.13.1 — Flatpack title character counts

Install `recording_studio_publishable` 0.13.1. No migration.

Social title and SEO title use Flatpack `TextInput` with `character_count: true` and `max_characters:` (70 and 60). `maxlength` stays on the input. The gem no longer draws its own counter paragraph or runs the inline title-counter script. The social image picker script is unchanged.

Counter text comes from Flatpack (`%{count}/%{limit} characters`). Flatpack ships English. A host that needs another language adds `flat_pack.text.characters_with_limit`.

`form.character_count` is still in this gem's locale files. Nothing uses it.

A host that copied the old counter markup should delete it and pass the Flatpack kwargs instead.

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
