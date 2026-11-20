# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "zeitwerk"

class SecurityAndRuntimeTest < Minitest::Test
  include ActiveJob::TestHelper

  def setup
    clear_enqueued_jobs
    clear_performed_jobs
    User.delete_all
    RailsAsyncMethods.reset_configuration!
  end

  def test_enqueue_time_allowlist_and_visibility_enforcement
    user = User.create!(name: "Ada")

    assert_raises(RailsAsyncMethods::UnauthorizedMethodError) { user.async.destroy! }
    assert_raises(RailsAsyncMethods::UnauthorizedMethodError) { user.async.undeclared_method }
    assert_raises(RailsAsyncMethods::UnauthorizedMethodError) { user.async.instance_eval("1 + 1") }
    assert_raises(RailsAsyncMethods::UnauthorizedMethodError) { user.async.send(:ping) }

    # Protected & private methods declared async are still refused at enqueue time
    assert_raises(NoMethodError) { user.async.protected_work }
    assert_raises(NoMethodError) { user.async.private_work }
  end

  def test_perform_time_defense_in_depth_blocks_tampered_job_payloads
    user = User.create!(name: "Ada")

    # Simulates an attacker tampering with Redis/SQL job rows directly
    assert_raises(RailsAsyncMethods::UnauthorizedMethodError) do
      RailsAsyncMethods::DispatchJob.perform_now(user, "destroy!", [], {})
    end

    assert_raises(RailsAsyncMethods::UnauthorizedMethodError) do
      RailsAsyncMethods::DispatchJob.perform_now(user, "instance_eval", ["1 + 1"], {})
    end

    assert_raises(RailsAsyncMethods::UnauthorizedMethodError) do
      RailsAsyncMethods::DispatchJob.perform_now("arbitrary_string", "instance_eval", ["1 + 1"], {})
    end

    assert_raises(RailsAsyncMethods::UnauthorizedMethodError) do
      RailsAsyncMethods::DispatchJob.perform_now(
        RailsAsyncMethods::ClassTarget.new(class_name: "User"),
        "delete_all",
        [],
        {}
      )
    end

    assert User.exists?(user.id)
  end

  def test_invalid_job_class_rejected
    user = User.create!(name: "Ada")

    assert_raises(RailsAsyncMethods::InvalidJobClassError) do
      user.async(job: String).ping
    end

    assert_raises(RailsAsyncMethods::InvalidJobClassError) do
      user.async(job: "Kernel").ping
    end

    assert_raises(RailsAsyncMethods::InvalidJobClassError) do
      user.async(job: Class.new(ActiveJob::Base)).ping
    end
  end

  def test_full_active_job_json_serialization_round_trip
    user = User.create!(name: "Ada")
    class_target = RailsAsyncMethods::ClassTarget.new(class_name: "StatelessService")

    raw_instance = ActiveJob::Arguments.serialize([user, "record_call", ["Hi"], { urgent: false, retries: 2 }])
    json_instance = JSON.parse(JSON.generate(raw_instance))
    deserialized_instance = ActiveJob::Arguments.deserialize(json_instance)

    assert_equal user, deserialized_instance[0]
    assert_equal "record_call", deserialized_instance[1]
    assert_equal ["Hi"], deserialized_instance[2]
    assert_equal({ urgent: false, retries: 2 }, deserialized_instance[3])

    raw_class = ActiveJob::Arguments.serialize([class_target, "call", ["inv-9"], { mode: :slow }])
    json_class = JSON.parse(JSON.generate(raw_class))
    deserialized_class = ActiveJob::Arguments.deserialize(json_class)

    assert_equal class_target, deserialized_class[0]
    assert_equal StatelessService, deserialized_class[0].resolve
    assert_equal({ mode: :slow }, deserialized_class[3])
  end

  def test_transaction_commit_deferral_and_rollback_suppression
    skip "ActiveJob enqueue_after_transaction_commit not supported on this Rails version" unless
      RailsAsyncMethods::DispatchJob.respond_to?(:enqueue_after_transaction_commit)

    # 1. Enqueue is deferred until COMMIT
    ActiveRecord::Base.transaction do
      user = User.create!(name: "TxUser")
      user.async.ping
      assert_equal 0, enqueued_jobs.size, "Job must not enqueue before transaction COMMIT"
    end
    assert_equal 1, enqueued_jobs.size, "Job must enqueue after transaction COMMIT"

    clear_enqueued_jobs

    # 2. Enqueue is suppressed on ROLLBACK
    ActiveRecord::Base.transaction do
      user = User.create!(name: "RolledBack")
      user.async.ping
      raise ActiveRecord::Rollback
    end
    assert_equal 0, enqueued_jobs.size, "Job must not enqueue after transaction ROLLBACK"
  end

  def test_zeitwerk_reload_does_not_hold_stale_job_class_references
    Dir.mktmpdir do |dir|
      job_file = File.join(dir, "reloadable_async_job.rb")
      File.write(job_file, <<~RUBY)
        class ReloadableAsyncJob < ActiveJob::Base
          include RailsAsyncMethods::Dispatcher
          def self.version_tag = :v1
        end
      RUBY

      loader = Zeitwerk::Loader.new
      loader.push_dir(dir)
      loader.enable_reloading
      loader.setup

      model_class = Class.new(ApplicationRecord) do
        self.table_name = "users"
        async_method :ping, job: "ReloadableAsyncJob"
        def ping; end
      end

      user = model_class.create!(name: "Reload")
      first_job = user.async_job.ping
      assert_equal :v1, first_job.class.version_tag

      # Modify and reload via Zeitwerk
      File.write(job_file, <<~RUBY)
        class ReloadableAsyncJob < ActiveJob::Base
          include RailsAsyncMethods::Dispatcher
          def self.version_tag = :v2
        end
      RUBY
      loader.reload

      second_job = user.async_job.ping
      assert_equal :v2, second_job.class.version_tag
      refute_equal first_job.class.object_id, second_job.class.object_id
    ensure
      loader&.unload
    end
  end

  def test_gemspec_validates_cleanly
    spec = Gem::Specification.load(File.expand_path("../rails_async_methods.gemspec", __dir__))
    assert spec.validate(false)
  end
end
