# frozen_string_literal: true

require "test_helper"

class RailsAsyncMethodsTest < Minitest::Test
  include ActiveJob::TestHelper
  include RailsAsyncMethods::TestHelper

  def setup
    clear_enqueued_jobs
    clear_performed_jobs
    User.delete_all
    StatelessService.calls.clear
    GlobalIdPoro::STORE.clear
    CustomDispatchJob.around_ran = false
    RailsAsyncMethods.reset_configuration!
  end

  def test_zero_global_object_pollution
    refute Object.method_defined?(:async)
    refute Object.method_defined?(:to_active_job)
    refute_respond_to PlainObject.new, :async
    refute_respond_to "hello", :async
    refute_respond_to 42, :async
  end

  def test_preserves_default_positional_and_keyword_arguments
    user = User.create!(name: "Ada")

    perform_enqueued_jobs do
      user.async.record_call
    end

    assert_equal ["Welcome", true, 3], JSON.parse(user.reload.last_call)
  end

  def test_passes_explicit_positional_and_keyword_arguments
    user = User.create!(name: "Ada")

    perform_enqueued_jobs do
      user.async.record_call("Hello", urgent: false, retries: 7)
    end

    assert_equal ["Hello", false, 7], JSON.parse(user.reload.last_call)
  end

  def test_inline_async_method_def_syntax
    user = User.create!(name: "Ada")

    perform_enqueued_jobs do
      user.async.ping
    end

    assert_equal "pong", user.reload.last_call
  end

  def test_no_variable_shadowing_on_tricky_parameter_names
    user = User.create!(name: "Ada")

    perform_enqueued_jobs do
      user.async.tricky_param_names("send", "instance_eval", "system('id')", "extra")
    end

    assert_equal ["send", "instance_eval", "system('id')", "extra"], JSON.parse(user.reload.last_call)
  end

  def test_basic_object_proxy_forwards_object_method_names
    user = User.create!(name: "Ada")

    perform_enqueued_jobs do
      user.async.options
    end
    assert_equal "model_options_called", user.reload.last_call

    perform_enqueued_jobs do
      user.async.display("banner")
    end
    assert_equal "display:banner", user.reload.last_call
  end

  def test_proxy_respond_to_works_with_one_and_two_arguments
    user = User.create!(name: "Ada")

    assert user.async.respond_to?(:ping)
    assert user.async.respond_to?(:ping, true)
    refute user.async.respond_to?(:undeclared_method)
    refute user.async.respond_to?(:protected_work)
    refute user.async.respond_to?(:private_work)
  end

  def test_blocks_are_loudly_rejected
    user = User.create!(name: "Ada")

    err = assert_raises(ArgumentError) do
      user.async.ping { "nope" }
    end
    assert_match(/Cannot pass a block/, err.message)
  end

  def test_unpersisted_active_record_raises_unpersisted_target_error
    user = User.new(name: "Unsaved")

    assert_raises(RailsAsyncMethods::UnpersistedTargetError) do
      user.async.ping
    end
  end

  def test_class_methods_and_stateless_services
    u1 = User.create!(name: "One")
    u2 = User.create!(name: "Two")

    assert_async_method_enqueued(User, :bulk_cleanup, kwargs: { older_than: u1.id }, queue: "maintenance") do
      User.async.bulk_cleanup(older_than: u1.id)
    end

    perform_enqueued_jobs do
      User.async.bulk_cleanup(older_than: u1.id)
      StatelessService.async.call("invoice-1", mode: :thorough)
    end

    assert_nil u1.reload.last_call
    assert_equal "cleaned", u2.reload.last_call
    assert_equal [["invoice-1", :thorough]], StatelessService.calls
  end

  def test_global_id_poro_works_and_stateful_poro_fails_loudly
    poro = GlobalIdPoro.new("42")

    perform_enqueued_jobs do
      poro.async.push("hello")
    end
    assert_equal ["hello"], poro.events

    err = assert_raises(RailsAsyncMethods::UnserializableTargetError) do
      StatefulPoro.new.async.run
    end
    assert_match(/GlobalID::Identification/, err.message)
  end

  def test_anonymous_class_fails_loudly
    anon = Class.new do
      include RailsAsyncMethods
      async_class_method :work
      def self.work; end
    end

    assert_raises(RailsAsyncMethods::UnserializableTargetError) do
      anon.async.work
    end
  end

  def test_dynamic_options_and_call_site_overrides
    vip = User.create!(name: "vip")
    regular = User.create!(name: "regular")

    assert_async_method_enqueued(vip, :notify, args: ["hi"], queue: "high") do
      vip.async.notify("hi")
    end

    assert_async_method_enqueued(regular, :notify, args: ["hi"], queue: "low") do
      regular.async.notify("hi")
    end

    # Call-site override wins over declaration
    assert_async_method_enqueued(regular, :notify, args: ["urgent"], queue: "critical") do
      regular.async(queue: :critical).notify("urgent")
    end

    # Dynamic Proc wait_until evaluated at enqueue time
    job = vip.async.scheduled_via_proc
    assert_in_delta 1_900_000_000, job.scheduled_at.to_i, 1

    # Call-site wait_until overrides declaration wait:
    future = 2.hours.from_now
    job = vip.async(wait_until: future).delayed_call
    assert_in_delta future.to_i, job.scheduled_at.to_i, 2
  end

  def test_invalid_options_fail_loudly
    assert_raises(RailsAsyncMethods::InvalidOptionError) do
      Class.new(ApplicationRecord) do
        async_method :ping, wait_until: 1.hour.from_now
      end
    end

    assert_raises(RailsAsyncMethods::InvalidOptionError) do
      Class.new(ApplicationRecord) do
        async_method :ping, wait: 1.hour, wait_until: -> { 1.hour.from_now }
      end
    end

    assert_raises(ArgumentError) do
      Class.new(ApplicationRecord) do
        async_method :ping, queu: :typo
      end
    end

    assert_raises(RailsAsyncMethods::InvalidOptionError) do
      Class.new(ApplicationRecord) do
        async_method :ping, priority: :high
      end
    end
  end

  def test_subclass_inheritance_isolation_and_signature_override
    admin = AdminUser.create!(name: "Root")
    user = User.create!(name: "Regular")

    # Subclass override with extra keyword arg works without stale signature
    perform_enqueued_jobs do
      admin.async.notify("alert", channel: :sms)
      admin.async.admin_only
    end
    assert_equal "admin_only", admin.reload.last_call

    # Parent class did not inherit subclass's async declaration (copy-on-write)
    assert_raises(RailsAsyncMethods::UnauthorizedMethodError) do
      user.async.admin_only
    end
  end

  def test_custom_dispatch_job_and_perform_all_later_batching
    u1 = User.create!(name: "A")
    u2 = User.create!(name: "B")

    jobs = [u1, u2].map { |u| u.async_job(job: CustomDispatchJob, queue: :batch).ping }
    assert_equal 0, enqueued_jobs.size

    ActiveJob.perform_all_later(jobs)
    assert_equal 2, enqueued_jobs.size
    assert_equal CustomDispatchJob, enqueued_jobs.first[:job]
    assert_equal "batch", enqueued_jobs.first[:queue]

    perform_enqueued_jobs
    assert CustomDispatchJob.around_ran
    assert_equal "pong", u1.reload.last_call
    assert_equal "pong", u2.reload.last_call
  end

  def test_active_support_notifications_instrumentation
    user = User.create!(name: "Ada")
    events = []

    ActiveSupport::Notifications.subscribed(->(*args) { events << ActiveSupport::Notifications::Event.new(*args) }, "perform.rails_async_methods") do
      perform_enqueued_jobs { user.async.ping }
    end

    assert_equal 1, events.size
    assert_equal user, events.first.payload[:target]
    assert_equal :ping, events.first.payload[:method]
    assert_equal "RailsAsyncMethods::DispatchJob", events.first.payload[:job]
  end
end
