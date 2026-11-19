# frozen_string_literal: true

# Recording Studio 7.7 applies Recording.kept through registered filters.
# Trashable owns the trashed_at filter. The Gemfile pins it with require: false,
# so load the query entry and leave the Trashable engine unloaded.
require "recording_studio_trashable/query"
