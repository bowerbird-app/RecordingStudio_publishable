# Dummy App

This Rails app validates `recording_studio_publishable` inside a host application.

## What it demonstrates

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- a parent `Page` recording with one publishable child recording
- the FlatPack-based **Edit publishable info** screen
- reusable publishable status, summary, and quick action UI
- the default public route at `/published/:uuid/:slug`

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

## Useful Routes

- `/` - publishable demo home page
- `/recordings/:recording_id/publishable/edit` - edit publishable info
- `/published/:uuid/:slug` - default public route
- `/recording_studio` - mounted RecordingStudio engine
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods`, `/docs/components` - supporting docs
