# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-09-16

### Added
- `QuickActions` is a Flatpack status dropdown for host pages. The closed button names Draft, the scheduled date (for example `Jan 22`), or Published. The menu holds `Publish now` (`rocket-launch`), `Schedule` on drafts, `Change schedule` when a date is already set, `Unpublish`, Preview or View, then SEO and Social. Draft uses `pencil-square`
- Draft and scheduled menus open Preview in a new tab at `/recordings/:recording_id/publishable/preview`. That route is for people who can see the page, renders the public template, and sends `noindex,nofollow`. Logged-out visitors get 404. Live menus open View at the public URL
- Inline transitions (`inline=1` or a Turbo Stream request) stay on the host page. Turbo Stream replaces the dropdown. HTML falls back to `redirect_back`
- Publish settings is a hub. Preview or View sits at the top of that list, then Schedule, SEO, and Social. Schedule in the dropdown opens the schedule screen. SEO and Social in the dropdown open those screens
- Inline publish and unpublish replace the dropdown only. They do not insert a success banner next to it
- Inline Turbo replace keeps the host `size` so a small Pages dropdown does not jump to medium after publish

### Changed
- Dummy home uses the dropdown in the Publish column. The dummy article page uses it for signed-in people. Dummy now loads Turbo so those PATCHes stay on the page
- Published uses Flatpack success style and the `check-circle` icon. Dummy Pages puts Page in the page title slot so there is space above the table
- Dummy seeds a scheduled Winter preview page so the three closed states can be shown
- The stuffed accordion publish form is gone. Job forms post back to the same update path with a `section` and return to that screen
- Search fields are Title in search and Description in search. The job is labeled SEO. Canonical URL and Search listing stay on that screen even when SEO tags are off
- Dummy Pages uses a plus icon with the label Page. The Pages table column for listing is SEO
- Schedule, SEO, Social, and the Publish hub stay left-aligned. Job forms and the hub list use a narrower desktop width. Those screens hide the workspace switcher and Sign out
- Scheduled dropdowns use `Change schedule` and show the date on the closed button. Draft and published menus still say `Schedule`
- The Scheduled trigger uses Flatpack default style, not warning

### Upgrade Notes
- Render `RecordingStudioPublishable::QuickActions::Component` (or `render_publishable_quick_actions`) on host pages where people should see and change publish state
- The component always sends `inline=1`. Those requests no longer open the gem Publish or success screens
- Publish settings opens the hub. That list starts with Preview or View, then Schedule, SEO, and Social. Those jobs open `/recordings/:recording_id/publishable/schedule`, `/search`, and `/social`
- Preview is not a query param on the public URL. People who can see the page can open Preview. Live menus use View. Public templates can render `publishable_preview_badge`
- PATCH without `inline=1` still redirects to the gem screens, as before
- Hosts that overrode `edit.html.erb` as one form should switch to the hub and the job screens
- The Search job is now labeled SEO. The path is still `/publishable/search`
- Bump to `recording_studio_publishable` `0.3.0`

## [0.2.1] - 2026-09-02

Cloud Agent install no longer fails a warm environment rebuild. Skills still
fetch at Build.

### Fixed

- `.cursor/install.sh` skips apt, ruby-build, db:prepare, and tailwind when
  Ruby, bundle, and Postgres are already usable. A skippable provision
  failure no longer fails the Build. Fetch-skills always runs last.

### Added

- Cloud Agent Builds fetch RecordingStudio_cursor_plugin through
  `.cursor/fetch-skills.sh`. The repository tracks `.cursor/environment.json`,
  `.cursor/install.sh`, `.cursor/start.sh`, and `.cursor/fetch-skills.sh`.
  Fetched skills and plugin rules stay gitignored.

### Upgrade Notes

- No host or schema changes. Rebuild the Cloud Agent environment with Draft
  off so Build loads the pack.

## [0.2.0] - 2026-08-21

### Breaking
- Host enablement is only `include RecordingStudio::Capabilities::Publishable.to(**opts)` on opted-in recordables. `RecordingStudioPublishable::ParentRecordable` and `recording_studio_publishable(...)` are removed
- The engine does not include publish helpers on every `RecordingStudio::Recording`. Scopes live on opted-in types only
- Runtime dependency is now RecordingStudio `~> 4.2`
- `config.layout` is the layout setter. `config.default_layout` is removed
- `publishable_head_tags` no longer accepts `title:`
- Path, schedule, and SEO come from `.to` keywords plus `capability_options` / `register_public_renderer`. Class attributes `recording_studio_publishable_path_template`, `_schedule_enabled`, and `_seo_enabled` are removed

### Added
- Canonical `.to` wrapper around core 4.2.0 `RecordingStudio::Capabilities.include_for(:publishable, **options)`
- Capability registration with `child_recordables: ["RecordingStudioPublishable::Publishable"]`
- Soft-detection for optional `trashed_at` so Trashable can stay out of the gemspec DAG
- `publishable_head_tags` now emits `meta name="robots"` from `meta_robots` (default `index,follow`)
- Canonical URL is an optional override on the management screen and Update service. Blank uses the public URL
- `indexable` / `indexable?` on opted-in parent types for public lists and search

### Changed
- Dummy pins Recording Studio `v4.2.0`, Accessible `v0.6.1`, Attachable `0.4.0`, Flatpack `v0.1.133`, and dummy-only Root Switchable `v0.5.0`
- Dummy authenticated layout is Recording Studio's default layout (`UsesDefaultLayout`) with PageNav back + close, workspace switcher, and Sign out. There is no homemade Dummy publishables landing or sidebar
- Dummy layouts set Flatpack's built-in `<html data-theme="rounded">` (not custom CSS). Stylesheets load in kit order (`flat_pack/variables`, `flat_pack/application`, `flat_pack/rich_text`, then Tailwind) so Table and Accordion match https://flatpack.bowerbird.io/
- Dummy Tailwind scans Flatpack components (and a `tmp/tailwind` mirror) so table and accordion utilities such as `w-5` / `h-5` are present. Importmap lazy-loads Flatpack controllers like gem_template v0.2.0
- Publish edit/success use the layout PageNav (`page_nav_anchor_url` mapped to Flatpack `anchor_href`) so there is one close control, not a second PageNav in the gem view
- The publish screen accordion for canonical URL and listing is labeled **Search engines**, not Search. Field copy stays Canonical URL and Search listing
- README now describes Publishable rather than GemTemplate
- `publishable_head_tags` no longer emits `<title>`. Layouts yield `publishable_document_title` so there is one document title

### Upgrade Notes
- Host apps must move to RecordingStudio `~> 4.2` with this gem
- Replace `include RecordingStudioPublishable::ParentRecordable` and `recording_studio_publishable(...)` with `include RecordingStudio::Capabilities::Publishable.to(**opts)`. There is no alias
- Use `config.layout`. Do not set `config.default_layout`
- Stop passing `title:` to `publishable_head_tags`. Yield `publishable_document_title` from the layout or public view
- Do not read `recording_studio_publishable_path_template`, `recording_studio_publishable_schedule_enabled`, or `recording_studio_publishable_seo_enabled` from the model. Use `.to` keywords, `RecordingStudio.capability_options(:publishable, for: Type)`, and `configuration.public_path_for`
- Do not add `recording_studio_trashable` unless the host actually uses trash. Publish queries skip `trashed_at` when the column is absent
- Run `bin/rails generate recording_studio_publishable:migrations` and `bin/rails db:migrate` so the unique publishable-child index is created without assuming `trashed_at`
- Use `Page.indexable` / `page.indexable?` for public lists and search. Do not invent a parallel indexable helper
- Canonical URL and search listing are on the publish management screen (Search engines accordion) and the Update service. Blank canonical uses the public URL. If you overrode the edit view and still label that accordion Search, rename it to Search engines

## [0.1.2] - 2026-06-05

### Changed
- Updated RecordingStudio integration to strict declaration mode in the dummy app and aligned addon dependency locks.
- Added optional Active Storage service switching via `ACTIVE_STORAGE_SERVICE` for development/production, with S3 smoke-test support in dummy app dependencies.

### Changed
- Bumped the dummy app FlatPack dependency from `v0.1.33` to `v0.1.74` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/recording_studio_publishable/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.3.0
[0.2.1]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.2.1
[0.2.0]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.2.0
[0.1.2]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.1.0
