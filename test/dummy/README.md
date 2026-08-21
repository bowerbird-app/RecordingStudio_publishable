# Dummy App

This Rails app validates `recording_studio_publishable` inside a host application on Recording Studio 4.2.

## What it demonstrates

- Devise authentication with seeded admin and viewer users
- `Current.actor` wiring for Recording Studio events
- opt-in `include RecordingStudio::Capabilities::Publishable.to(...)` on Page and Article
- a parent `Page` recording with one publishable child recording
- Recording Studio's default layout plus Flatpack CSS and JS
- the FlatPack-based **Edit publishable info** screen, including Canonical URL and search listing
- the default public route at `/published/:uuid/:slug`
- seeded published indexable, published hidden-from-search, and unpublished pages so head tags and `indexable?` can be checked

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

## Useful Routes

- `/` - publishable demo home page
- `/recordings/:recording_id/publishable/edit` - edit publishable info
- `/published/:uuid/:slug` - default public route
- `/recording_studio` - mounted RecordingStudio engine
- `/docs/headers` - preview generated canonical, Open Graph, and Twitter header values
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods`, `/docs/components` - supporting docs
