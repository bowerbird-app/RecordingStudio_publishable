# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Dummy pins Recording Studio `v4.2.0`, Accessible `v0.6.1`, Attachable `0.4.0`, and Flatpack `v0.1.133`
- Dummy authenticated layout is Recording Studio's default layout plus Flatpack CSS/JS (`UsesDefaultLayout`, `config.layout = "recording_studio/default_layout"`); Devise keeps its own sign-in layout
- Publish edit/success PageNav close control uses Flatpack `anchor_href` so the close URL still wires on Flatpack `v0.1.133`
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
- Canonical URL and search listing are on the publish management screen and the Update service. Blank canonical uses the public URL

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

[Unreleased]: https://github.com/bowerbird-app/recording_studio_publishable/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.2.0
[0.1.2]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/recording_studio_publishable/releases/tag/v0.1.0
