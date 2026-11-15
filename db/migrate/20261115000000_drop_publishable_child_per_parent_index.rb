# frozen_string_literal: true

class DropPublishableChildPerParentIndex < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_rs_publishable_child_per_parent"
  RECORDINGS = :recording_studio_recordings
  CONCURRENT_LOCK_TIMEOUT = "0"
  CONCURRENT_STATEMENT_TIMEOUT = "0"

  disable_ddl_transaction!

  def up
    return unless index_exists?(RECORDINGS, name: INDEX_NAME)

    with_concurrent_lock_timeout do
      remove_index RECORDINGS,
                   name: INDEX_NAME,
                   algorithm: :concurrently,
                   if_exists: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, <<~MSG
      Refusing to recreate #{INDEX_NAME}.
      One publishable child per parent is index_recording_studio_recordings_on_single_child.
      That index counts trashed rows. Generate it after this drop:

        bin/rails generate recording_studio:single_child_index
        bin/rails db:migrate
    MSG
  end

  private

  # 0 waits. A short lock_timeout or statement_timeout cancels that wait.
  def with_concurrent_lock_timeout
    previous_lock_timeout = select_value("SHOW lock_timeout")
    previous_statement_timeout = select_value("SHOW statement_timeout")
    execute("SET lock_timeout = #{connection.quote(CONCURRENT_LOCK_TIMEOUT)}")
    execute("SET statement_timeout = #{connection.quote(CONCURRENT_STATEMENT_TIMEOUT)}")
    yield
  ensure
    restore_timeout("statement_timeout", previous_statement_timeout)
    restore_timeout("lock_timeout", previous_lock_timeout)
  end

  def restore_timeout(setting, previous)
    return if previous.nil?

    execute("SET #{setting} = #{connection.quote(previous)}")
  end
end
