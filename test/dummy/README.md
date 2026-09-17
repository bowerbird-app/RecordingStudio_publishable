# Dummy App

This Rails app validates `recording_studio_publishable` inside a host application on Recording Studio 4.2.

## What it demonstrates

- Devise authentication with seeded admin and viewer users
- `Current.actor` wiring for Recording Studio events
- opt-in `include RecordingStudio::Capabilities::Publishable.to(...)` on Page and Article. Both collect Title and Description
- a parent `Page` recording with one publishable child recording
- Recording Studio's default layout (`RecordingStudio::UsesDefaultLayout`) with PageNav back + close. Pages home keeps the workspace switcher and Sign out. Publish screens hide those right slots
- Flatpack's built-in `rounded` theme on `<html data-theme="rounded">` (not custom CSS) on every dummy layout, including Devise and public pages
- Flatpack CSS and JS loaded the way the [live kit](https://flatpack.bowerbird.io/) does: `flat_pack/variables`, `flat_pack/application`, `flat_pack/rich_text`, then host Tailwind; stylesheets in `manifest.js`; Flatpack controllers lazy-loaded from `importmap.rb`
- Publish settings is a hub. The list starts with Preview or View, then Schedule, SEO, and Social. On desktop the list stays left-aligned at a narrower width; the title and dropdown keep the full layout width
- a host **publish dropdown** on the Pages table (`QuickActions`) so a page can go live or unpublish without opening that screen. Schedule, SEO, and Social in the dropdown open those screens. Draft and scheduled menus include Preview. Live menus include View
- the default public route at `/published/:uuid/:slug`
- seeded published indexable, published hidden-from-search, scheduled, and draft pages so head tags, `indexable?`, and the three dropdown states can be checked

## Seeded records

`bin/rails db:setup` (or `bin/rails db:seed` on an existing database) creates published, scheduled, and draft pages so screenshots and checks are not empty lists:

| Title | Type | Publish state | SEO |
| --- | --- | --- | --- |
| Launch Checklist | Page | published | Indexable |
| Staff-only notes | Page | published | noindex |
| Coming soon | Page | draft | Not live |
| Winter preview | Page | scheduled | Not live |
| Spring Release Notes | Article | published | Indexable |

Home (`/`) lists all five. Public routes only exist for the published rows. Preview is a signed-in route for people who can see Coming soon or Winter preview. Logged-out visitors get 404. It is not the public URL.

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

The admin account has edit/admin access through RecordingStudio Accessible. The viewer account has view-only access and cannot change publish settings, but can open Preview.

Authenticated pages include `RecordingStudio::UsesDefaultLayout` and `RecordingStudio::RootSwitchable::ControllerSupport`. Publishable `config.layout` is `recording_studio/default_layout`. Dummy overrides that layout only so `<html data-theme="rounded">` is set — Flatpack's built-in rounded theme, the same one the live kit uses. Devise `application` layout sets the same attribute. Stylesheets load like the kit (`flat_pack/variables`, `flat_pack/application`, `flat_pack/rich_text`, then Tailwind). Dummy `config/importmap.rb` pins `@hotwired/turbo-rails` and Flatpack controllers with `preload: false`; `app/javascript/application.js` imports Turbo; `app/javascript/controllers/index.js` lazy-loads Stimulus controllers. `app/assets/config/manifest.js` links the Flatpack stylesheets. Home is the Flatpack Table of Pages. Publish settings is a hub that starts with Preview or View, then Schedule, SEO, and Social. The SEO screen for a page includes Title and Description. noindex and Canonical URL sit under Advanced. The hub list and job forms use a narrower desktop width and stay left-aligned. The hub, Schedule, SEO, and Social hide the workspace switcher and Sign out. There is no custom sidebar and no custom CSS to shrink chevrons or unstack rows.

## Useful Routes

- `/` - publishable demo home page
- `/recordings/:recording_id/publishable/edit` - Publish settings hub
- `/recordings/:recording_id/publishable/schedule` - schedule screen
- `/recordings/:recording_id/publishable/search` - SEO screen
- `/recordings/:recording_id/publishable/social` - social preview screen
- `/recordings/:recording_id/publishable/preview` - signed-in preview of a draft or scheduled page
- `/published/:uuid/:slug` - default public route
- `/recording_studio` - mounted RecordingStudio engine
- `/docs/headers` - preview generated canonical, Open Graph, and Twitter header values
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods`, `/docs/components` - supporting docs
