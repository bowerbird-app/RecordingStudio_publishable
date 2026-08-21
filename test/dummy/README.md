# Dummy App

This Rails app validates `recording_studio_publishable` inside a host application on Recording Studio 4.2.

## What it demonstrates

- Devise authentication with seeded admin and viewer users
- `Current.actor` wiring for Recording Studio events
- opt-in `include RecordingStudio::Capabilities::Publishable.to(...)` on Page and Article
- a parent `Page` recording with one publishable child recording
- Recording Studio's default layout (`RecordingStudio::UsesDefaultLayout`) with PageNav back + close, workspace switcher, and Sign out
- Flatpack CSS and JS loaded for real: Tailwind + `flat_pack/variables` + `flat_pack/rich_text` in the default layout, Flatpack stylesheets in `manifest.js`, Flatpack controllers lazy-loaded from `importmap.rb`
- the FlatPack-based **Edit publishable info** screen, including Canonical URL and search listing
- the default public route at `/published/:uuid/:slug`
- seeded published indexable, published hidden-from-search, and unpublished pages so head tags and `indexable?` can be checked

## Seeded records

`bin/rails db:setup` (or `bin/rails db:seed` on an existing database) creates both a live page and a draft so screenshots and checks are not empty lists:

| Title | Type | Publish state | Search |
| --- | --- | --- | --- |
| Launch Checklist | Page | published | In search |
| Staff-only notes | Page | published | Hidden from search |
| Coming soon | Page | draft | Not live |
| Spring Release Notes | Article | published | In search |

Home (`/`) lists all four. Public routes only exist for the published rows.

To re-seed without resetting the database:

```bash
cd test/dummy
bin/rails db:seed
```

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Sign in with:

- Email: `admin@admin.com`
- Password: `Password`

Or test unauthorized edit behavior with:

- Email: `viewer@admin.com`
- Password: `Password`

The admin account has edit/admin access through RecordingStudio Accessible. The viewer account has view-only access and should be unauthorized for publishable edit actions.

Authenticated pages include `RecordingStudio::UsesDefaultLayout` and `RecordingStudio::RootSwitchable::ControllerSupport`. Publishable `config.layout` is `recording_studio/default_layout`. That layout loads Tailwind, `flat_pack/variables`, `flat_pack/rich_text`, and the importmap. Dummy `config/importmap.rb` pins Flatpack controllers with `preload: false`; `app/javascript/controllers/index.js` lazy-loads them. `app/assets/config/manifest.js` links the Flatpack stylesheets. `bin/rails tailwindcss:build` scans Flatpack components so table rows and accordion chevrons (`w-5 h-5`) size correctly. Home is the default-layout Pages table, not a homemade Dummy publishables landing. There is no custom sidebar.

## Useful Routes

- `/` - publishable demo home page
- `/recordings/:recording_id/publishable/edit` - edit publishable info
- `/published/:uuid/:slug` - default public route
- `/recording_studio` - mounted RecordingStudio engine
- `/docs/headers` - preview generated canonical, Open Graph, and Twitter header values
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods`, `/docs/components` - supporting docs
