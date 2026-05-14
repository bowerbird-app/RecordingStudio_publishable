# RecordingStudio_publishable

Recording Studio Publishable adds a reusable **publishable child recording** to a parent `RecordingStudio::Recording`.

## What the gem provides

- a `RecordingStudioPublishable::Publishable` recordable for public metadata and publish state
- one publishable child recording per parent recording
- current-state helpers for draft, scheduled, published, and unpublished content
- a default public route at `/published/:uuid/:slug`
- a FlatPack-based **Edit publishable info** screen
- reusable publishable UI partials for a status badge, quick actions, and a summary card
- a dummy app that demonstrates a `Page` recording with a publishable child recording

Public rendering always uses the parent recording's latest/current recordable. The publishable recordable stores the current public configuration only; audit history belongs in RecordingStudio events.

## Core model

- **parent recording** - the real content item
- **publishable child recording** - the child `RecordingStudio::Recording` whose recordable is `RecordingStudioPublishable::Publishable`
- **publishable recordable** - slug, status, schedule, and SEO/social fields for the current public state

## Dummy app demo

The dummy app seeds:

- one workspace root recording
- a folder and a page beneath that root
- one publishable child recording for the page
- a mounted edit flow and default public route

Useful routes:

- `/` - demo landing page
- `/recordings/:recording_id/publishable/edit` - edit publishable info for a parent recording
- `/published/:uuid/:slug` - default public route
- `/docs/*` - dummy app supporting docs

## Host app setup

Run `bin/rails generate recording_studio_publishable:install` in the host app.

The install generator will:

- mount the engine and add the initializer
- copy the engine migrations into `db/migrate`
- append a publishable seed template to `db/seeds.rb`
- optionally add `config/recording_studio_publishable.yml`

After that, run `bin/rails db:migrate`, review the generated `db/seeds.rb` snippet, and either replace the example parent-recording lookup or set `RECORDING_STUDIO_PUBLISHABLE_PARENT_ID` before `bin/rails db:seed`.

## Running tests

From the repository root:

```bash
bundle exec rake test
bundle exec rake app:test
bundle exec rubocop
```

If dummy app boot, assets, or migrations change, also run:

```bash
cd test/dummy
bundle exec rake db:migrate RAILS_ENV=test
bundle exec rails tailwindcss:build
```

## Notes

- `RecordingStudioAccessible` is used when it is present to authorize management actions against the **parent recording**.
- `docs/gem_template/` remains preserved as template architecture reference material.
