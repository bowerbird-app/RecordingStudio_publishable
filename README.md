# Recording Studio Publishable

Recording Studio Publishable is the opt-in publish-state addon for `RecordingStudio`.

A parent recordable type such as a page or article can hold one child publishable recording. That child stores slug, schedule, SEO, and social card state. Installing the gem does not enable publish behavior on every recordable.

## What the gem provides

- gem name: `recording_studio_publishable`
- Ruby namespace: `RecordingStudioPublishable`
- capability opt-in through `RecordingStudio::Capabilities::Publishable.to`
- a child `RecordingStudioPublishable::Publishable` recordable that holds publish state
- scopes on opted-in parent types: `published`, `scheduled`, `draft`, `unpublished`, plus window filters
- recording helpers such as `publishable_child_recording`, `current_publishable`, and `publishable_public_path`
- public routing and Flatpack management screens for the current publishable child

Trashable is optional. Publishable does not depend on it. Query SQL only mentions `trashed_at` when that column exists.

## Installation

Add the gems to your host app. This addon requires Recording Studio 4.2.0 or newer:

```ruby
gem "recording_studio"
gem "recording_studio_publishable"
```

Then run:

```bash
bundle install
bin/rails generate recording_studio_publishable:install
bin/rails generate recording_studio_publishable:migrations
bin/rails db:migrate
```

## Setup

Mount the engine if you did not use the install generator:

```ruby
mount RecordingStudioPublishable::Engine, at: "/"
```

Configure RecordingStudio normally, then enable Publishable only on the types that should have public publish state:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = %w[
    Workspace
    Folder
    Page
    Article
    RecordingStudioPublishable::Publishable
  ]
  config.actor = -> { Current.actor }
end

class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", plural_label: "Workspaces", root: true
end

class Folder < ApplicationRecord
  recording_studio_recordable label: "Folder", root: false, allowed_parent_types: %w[Workspace Folder]
end

class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: %w[Workspace Folder Page]

  include RecordingStudio::Capabilities::Publishable.to(
    public_controller: "pages",
    public_action: :show,
    schedule: true,
    seo: false
  )
end

class Article < ApplicationRecord
  recording_studio_recordable label: "Article", root: false, allowed_parent_types: %w[Workspace Folder Article]

  include RecordingStudio::Capabilities::Publishable.to(
    public_controller: "articles",
    public_action: :show,
    path: "/blogs/:uuid/:slug",
    schedule: true,
    seo: true
  )
end
```

## Adding to a recordable

Recordables stay opt-in. Include the capability only on the models that should publish:

```ruby
class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: %w[Workspace Folder Page]

  include RecordingStudio::Capabilities::Publishable.to(
    public_controller: "pages",
    public_action: :show
  )
end
```

That registers the addon capability on `Page` while leaving other recordables, such as `Folder`, unchanged. Non-publishable types do not receive publish scopes.

`.to` wraps core 4.2.0 `RecordingStudio::Capabilities.include_for(:publishable, **options)`. Do not use `ParentRecordable` plus a `recording_studio_publishable` method as the host enablement API.

Optional `.to` keywords:

- `path` — public path template. Must include `:uuid`. Defaults to `/published/:uuid/:slug`
- `public_controller` / `public_action` / `public_layout` — how the public route renders the parent
- `schedule` — whether schedule controls are enabled (default `true`)
- `seo` — whether SEO-only tags are enabled (default `true`)

## Querying published parents

Scopes live on the opted-in recordable class:

```ruby
Page.published
Page.scheduled
Page.draft
Page.unpublished
Page.published_in(2.weeks.ago..Time.current)
page.published?
page.published_url
```

Recording instance helpers work on the parent recording after the capability is enabled:

```ruby
page_recording.current_publishable
page_recording.publishable_child_recording
page_recording.currently_published?
page_recording.publishable_public_path
```

## Dummy app

The dummy host at `test/dummy` pins Recording Studio `v4.2.0`, Accessible `v0.6.1`, Attachable `0.4.0`, and Flatpack `v0.1.133`. Authenticated dummy pages use Recording Studio's default layout plus Flatpack CSS and JS. Devise keeps its own sign-in layout.

Sign in with `admin@admin.com` / `Password`.

## Documentation

Engine internals from the original gem template remain in `docs/gem_template/` as architectural reference. This README and the dummy app are the source of truth for Publishable.
