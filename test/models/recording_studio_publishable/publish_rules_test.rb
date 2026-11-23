# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../test_helper"
require_relative "../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  class PublishRulesTest < ActiveSupport::TestCase
    PUBLIC_SCOPES = %i[published indexable].freeze
    RECORDABLE_SCOPES = %i[published scheduled draft unpublished indexable].freeze

    setup do
      @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Publish rules workspace"))
    end

    test "scopes match the instance predicates for each publish state" do
      freeze_time do
        catalog = build_catalog
        pages = catalog.fetch(:pages)
        recordings = tree_recordings

        RECORDABLE_SCOPES.each do |scope_name|
          expected = pages.select { |page| page.public_send(:"#{scope_name}?") }.map(&:id).sort
          actual = Page.public_send(scope_name).where(id: pages.map(&:id)).ids.sort

          assert_equal expected, actual, scope_name.to_s
        end

        expected_recordings = recordings.select(&:currently_published?).map(&:id).sort
        actual_recordings = RecordingStudio::Recording.currently_published.where(id: recordings.map(&:id)).ids.sort

        assert_equal expected_recordings, actual_recordings
        recordings.each do |recording|
          assert_equal recording.currently_published?, recording.published?, recording.id
        end

        plain = catalog.fetch(:plain)
        assert plain[:page].reload.indexable?
        assert plain[:recording].reload.indexable?
        assert_equal plain[:page].indexable_url, "https://press.example/kit"
        assert_includes expected_recordings, plain[:recording].id

        older = catalog.fetch(:older_live)
        newer = catalog.fetch(:newer_draft)
        refute newer[:page].published?
        refute newer[:page].indexable?
        assert older[:recording].reload.currently_published?
        refute newer[:recording].reload.currently_published?
        refute older[:recording].indexable?
        refute newer[:recording].indexable?

        tied = catalog.fetch(:tied)
        refute tied[:page].published?
        assert tied[:low].reload.currently_published?
        refute tied[:high].reload.currently_published?
      end
    end

    test "draft scheduled expired unpublished and trashed rows stay out of public scopes" do
      freeze_time do
        catalog = build_catalog
        hidden = %i[draft scheduled expired unpublish_edge unpublished trashed_parent trashed_child].map do |key|
          catalog.fetch(key).fetch(:page)
        end

        hidden.each do |page|
          PUBLIC_SCOPES.each do |scope_name|
            refute_includes Page.public_send(scope_name).ids, page.id
          end
          refute page.published?
          refute page.indexable?
        end

        [catalog.fetch(:trashed_parent), catalog.fetch(:trashed_child)].each do |entry|
          recording = entry.fetch(:recording).reload
          refute recording.currently_published?
          refute recording.published?
          refute_includes RecordingStudio::Recording.currently_published.ids, recording.id
          RECORDABLE_SCOPES.each do |scope_name|
            refute_includes Page.public_send(scope_name).ids, entry.fetch(:page).id
          end
        end

        expired = catalog.fetch(:expired).fetch(:page)
        %i[published indexable draft scheduled unpublished].each do |scope_name|
          refute_includes Page.public_send(scope_name).ids, expired.id
        end

        unpublished = catalog.fetch(:unpublished).fetch(:page)
        assert unpublished.unpublished?
        refute_includes Page.published.ids, unpublished.id
        refute_includes Page.indexable.ids, unpublished.id

        noindex_pages = %i[noindex noindex_token noindex_upper noindex_substring].map do |key|
          catalog.fetch(key).fetch(:page)
        end
        noindex_pages.each do |page|
          assert page.reload.published?
          refute page.indexable?
          assert_nil page.indexable_url
          refute_includes Page.indexable.ids, page.id
        end
      end
    end

    test "indexable limit and count stay a constant number of queries" do
      create_indexable_pages(4)
      small_list = sql_queries { Page.indexable.limit(12).to_a }
      small_count = sql_queries { Page.indexable.count }
      small_recordings = sql_queries { RecordingStudio::Recording.currently_published.limit(12).to_a }

      create_indexable_pages(12)
      large_list = sql_queries { Page.indexable.limit(12).to_a }
      large_count = sql_queries { Page.indexable.count }
      large_recordings = sql_queries { RecordingStudio::Recording.currently_published.limit(12).to_a }

      assert_equal 12, large_list.fetch(1).size
      assert_equal 1, small_list.fetch(0)
      assert_equal 1, small_count.fetch(0)
      assert_equal 1, small_recordings.fetch(0)
      assert_equal 1, large_list.fetch(0)
      assert_equal 1, large_count.fetch(0)
      assert_equal 1, large_recordings.fetch(0)
      assert_kind_of ActiveRecord::Relation, Page.indexable.limit(12)
      assert_kind_of ActiveRecord::Relation, RecordingStudio::Recording.currently_published.limit(12)

      page_ids = RecordingStudio::Recording.where(recordable_type: "Page").currently_published.limit(12).pluck(:id)
      assert_equal ["Page"], RecordingStudio::Recording.where(id: page_ids).distinct.pluck(:recordable_type)
      assert_empty RecordingStudio::Recording.where(id: @root.id).currently_published
    end

    test "indexable keeps a row whose public url does not resolve" do
      page = publish_page("unrouted", status: "published", slug: "unrouted-page").fetch(:page)

      RecordingStudioPublishable::Routing.stub(:url_for, nil) do
        assert_includes Page.indexable.ids, page.id
        refute page.indexable?
        assert_nil page.indexable_url
      end
    end

    private

    def build_catalog
      now = Time.current
      catalog = {}
      catalog[:plain] = publish_page(
        "plain",
        status: "published",
        slug: "plain-kit",
        canonical_url: "https://press.example/kit",
        meta_robots: "index,follow"
      )
      catalog[:draft] = publish_page("draft", status: "draft", slug: "draft-kit")
      catalog[:scheduled] = publish_page(
        "scheduled",
        status: "published",
        slug: "scheduled-kit",
        publish_at: 2.days.from_now
      )
      catalog[:expired] = stamp(
        publish_page("expired", status: "published", slug: "expired-kit"),
        publish_at: 2.days.ago,
        unpublish_at: 1.hour.ago
      )
      catalog[:publish_edge] = stamp(
        publish_page("publish-edge", status: "published", slug: "publish-edge"),
        publish_at: now,
        unpublish_at: nil
      )
      catalog[:unpublish_edge] = stamp(
        publish_page("unpublish-edge", status: "published", slug: "unpublish-edge"),
        publish_at: 1.hour.ago,
        unpublish_at: now
      )
      catalog[:unpublished] = stamp(
        publish_page("unpublished", status: "draft", slug: "unpublished-kit"),
        publish_at: nil,
        unpublish_at: 1.hour.ago,
        status: "draft"
      )
      catalog[:noindex] = publish_page(
        "noindex",
        status: "published",
        slug: "noindex-kit",
        meta_robots: "noindex,follow",
        canonical_url: "https://press.example/noindex"
      )
      catalog[:noindex_token] = publish_page(
        "noindex-token",
        status: "published",
        slug: "noindex-token",
        meta_robots: "index, noindex, follow",
        canonical_url: "https://press.example/noindex-token"
      )
      catalog[:noindex_upper] = publish_page(
        "noindex-upper",
        status: "published",
        slug: "noindex-upper",
        meta_robots: "NOINDEX",
        canonical_url: "https://press.example/noindex-upper"
      )
      catalog[:noindex_substring] = publish_page(
        "noindex-substring",
        status: "published",
        slug: "noindex-substring",
        meta_robots: "noindexable",
        canonical_url: "https://press.example/noindexable"
      )
      catalog[:spaced_robots] = publish_page(
        "spaced-robots",
        status: "published",
        slug: "spaced-robots",
        meta_robots: "no index",
        canonical_url: "https://press.example/spaced"
      )
      catalog[:blank_robots] = publish_page(
        "blank-robots",
        status: "published",
        slug: "blank-robots",
        meta_robots: "",
        canonical_url: "/press/blank-robots"
      )
      catalog[:ftp] = publish_page(
        "ftp",
        status: "published",
        slug: "ftp-kit",
        canonical_url: "ftp://press.example/kit"
      )
      catalog[:bad_canonical] = publish_page(
        "bad-canonical",
        status: "published",
        slug: "bad-canonical",
        canonical_url: "not a url"
      )
      catalog[:scheme_only] = publish_page(
        "scheme-only",
        status: "published",
        slug: "scheme-only",
        canonical_url: "http://"
      )
      catalog[:https_scheme_only] = publish_page(
        "https-scheme-only",
        status: "published",
        slug: "https-scheme-only",
        canonical_url: "https://"
      )
      catalog[:slash_host] = publish_page(
        "slash-host",
        status: "published",
        slug: "slash-host",
        canonical_url: "http:///missing-host"
      )
      catalog[:relative] = publish_page(
        "relative",
        status: "published",
        slug: "relative-kit",
        canonical_url: "/press/relative-kit"
      )
      catalog[:trashed_parent] = publish_page("trashed-parent", status: "published", slug: "trashed-parent")
      catalog[:trashed_parent].fetch(:recording).update_columns(trashed_at: now)
      catalog[:trashed_child] = publish_page("trashed-child", status: "published", slug: "trashed-child")
      catalog[:trashed_child].fetch(:recording).publishable_child_recording.update_columns(trashed_at: now)
      catalog[:older_live] = publish_page("older-live", status: "published", slug: "older-live", canonical_url: "https://press.example/older")
      catalog[:newer_draft] = add_parent(catalog[:older_live].fetch(:page), status: "draft", slug: "newer-draft")
      catalog[:older_live].fetch(:recording).update_columns(created_at: 3.days.ago)
      catalog[:tied] = tie_parents
      catalog[:pages] = catalog.except(:pages, :older_live, :newer_draft, :tied).values.map do |entry|
        entry.fetch(:page)
      end
      catalog[:pages] << catalog[:older_live].fetch(:page)
      catalog[:pages] << catalog[:tied].fetch(:page)
      catalog[:pages].uniq!
      catalog
    end

    def tie_parents
      page = Page.create!(title: "Tied parents")
      first = RecordingStudio::Recording.create!(recordable: page, parent_recording: @root)
      second = RecordingStudio::Recording.create!(recordable: page, parent_recording: @root)
      high_id = RecordingStudio::Recording.where(id: [first.id, second.id]).order(id: :desc).pick(:id)
      high = high_id == first.id ? first : second
      low = high == first ? second : first
      publish_on(low, status: "published", slug: "tied-low", canonical_url: "https://press.example/tied-low")
      publish_on(high, status: "draft", slug: "tied-high")
      stamp_time = 4.days.ago
      low.update_columns(created_at: stamp_time)
      high.update_columns(created_at: stamp_time)
      { page: page, low: low, high: high }
    end

    def publish_page(title, **attributes)
      page = Page.create!(title: title)
      recording = RecordingStudio::Recording.create!(recordable: page, parent_recording: @root)
      publish_on(recording, **attributes)
      { page: page, recording: recording }
    end

    def add_parent(page, **attributes)
      recording = RecordingStudio::Recording.create!(recordable: page, parent_recording: @root)
      publish_on(recording, **attributes)
      { page: page, recording: recording }
    end

    def publish_on(recording, **attributes)
      result = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: recording,
        attributes: attributes
      )
      flunk(result.inspect) unless result.success?

      result.value!
    end

    def stamp(entry, publish_at:, unpublish_at:, status: "published")
      publishable = entry.fetch(:recording).reload.current_publishable
      RecordingStudioPublishable::Publishable.where(id: publishable.id).update_all(
        status: status,
        publish_at: publish_at,
        unpublish_at: unpublish_at
      )
      entry
    end

    def tree_recordings
      root_id = @root.root_recording_id || @root.id
      RecordingStudio::Recording.where(root_recording_id: root_id).or(
        RecordingStudio::Recording.where(id: root_id)
      ).to_a
    end

    def create_indexable_pages(count)
      count.times do |index|
        publish_page(
          "listed-#{SecureRandom.hex(4)}-#{index}",
          status: "published",
          slug: "listed-#{SecureRandom.hex(4)}-#{index}",
          canonical_url: "https://press.example/listed-#{index}-#{SecureRandom.hex(4)}"
        )
      end
    end

    def sql_queries
      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql].to_s
        next if payload[:name] == "SCHEMA" || payload[:cached]
        next if sql.match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

        queries << sql
      end
      result = nil
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        result = yield
      end
      [queries.size, result]
    end
  end
end
