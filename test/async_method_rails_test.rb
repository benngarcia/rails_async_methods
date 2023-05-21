require "test_helper"
require 'pry'
class RailsAsyncMethodsTest < ActiveSupport::TestCase
  include DelayedJobRunner

  test "it has a version number" do
    assert RailsAsyncMethods::VERSION
  end

  test "it generates the abstract job" do
    system "cd test/dummy && rails generate rails_async_methods"
    assert File.exist? "test/dummy/app/jobs/rails_async_methods/abstract_job.rb"
  end

  test "it generates a delayed job when an async method is called" do
    ex = AsyncExample.create!(testfield: "not nil")
    assert_difference "Delayed::Job.count", 1 do
      ex.async_set_testfield_nil
    end

    run_last
    assert_nil ex.reload.testfield
  end

  test "it does not run on an unsaved record" do
    ex = AsyncExample.new
    assert_raises(RailsAsyncMethods::AsyncMethod::NotPersistedError) { ex.async_set_testfield_nil }
  end

  test "it does not accept a block" do
    ex = AsyncExample.create!
    # flunk { "block_given? gets confused about which context to check for block" }
  end

  test "it can correctly work with spread args and kwargs" do
    ex = AsyncExample.create!
    ex2 = AsyncExample.create!
    ex.async_method_with_args_spread_args_and_kwargs(1, 2, 3, **{ foo: :bar })
    ex2.method_with_args_spread_args_and_kwargs(1, 2, 3, **{ foo: :bar })
    run_last
    assert_equal ex.reload.testfield, ex2.reload.testfield

    ex.async_method_with_args_spread_args_and_kwargs(2, 3, 4, **{ foo: :bar })
    ex2.method_with_args_spread_args_and_kwargs(2, 3, 4, **{ foo: :bar })
    run_last
    assert_equal ex.reload.testfield, ex2.reload.testfield
  end

  test "it correctly utilizes a different queue when specified" do
    ex = AsyncExample.create!
    dj = ex.async_method_with_diff_queue

    assert_equal dj.queue_name, "fast"
  end

  test "it correctly sets wait and priority" do
    ex = AsyncExample.create!
    dj = ex.async_method_with_diff_wait_time_and_priority

    assert_in_delta dj.scheduled_at, 1.week.from_now.to_i, 60
    assert_equal dj.priority, -10
  end

  test "it correctly utilizes a diff prefix" do
    ex = AsyncExample.create!

    assert_respond_to ex, :auto_async_method_with_diff_prefix
    assert_not_respond_to ex, :async_method_with_diff_prefix
  end

  test "it correctly utlizes a custom job" do
    ex = AsyncExample.create!

    dj = ex.async_method_with_custom_job
    assert_equal(dj.class, ExampleCustomAsyncJob) # assert_instance_of not working
  end

  test "correctly passes arguments to a custom job" do
    ex = AsyncExample.create!

    dj = ex.async_method_with_custom_job_and_args
    assert_equal dj.class, ExampleCustomAsyncJob
    assert_equal dj.queue_name, 'custom'
  end

  test 'it can utilize the async core ext to return an async wrapper' do
    ex = AsyncExample.create!(testfield: 'not nil')
    assert_difference 'Delayed::Job.count', 1 do
      async(ex).set_testfield_nil
    end
    run_last

    assert_nil ex.reload.testfield
  end

  test 'it can also be called as a chainable method' do
    ex = AsyncExample.create!(testfield: 'not nil')
    assert_difference 'Delayed::Job.count', 1 do
      ex.to_active_job.set_testfield_nil
    end
    run_last

    assert_nil ex.reload.testfield
  end

  test 'to_active_job can take options' do
    ex = AsyncExample.create!(testfield: 'not nil')
    dj = ex.to_active_job(queue: :fast, job: ExampleCustomAsyncJob).set_testfield_nil

    assert_equal dj.queue_name, 'fast'
    assert_equal dj.class, ExampleCustomAsyncJob
    run_last
    assert_nil ex.reload.testfield
  end

  test 'async global helper can take options' do
    ex = AsyncExample.create! testfield: 'not nil'
    dj = async(ex, queue: :fast, job: ExampleCustomAsyncJob, priority: 10, wait: 1.week).set_testfield_nil

    assert_equal dj.queue_name, 'fast'
    assert_equal dj.class, ExampleCustomAsyncJob
    assert_not_nil ex.reload.testfield
    assert_in_delta dj.scheduled_at, 1.week.from_now.to_i, 60
    run_last
    assert_nil ex.reload.testfield
  end

  test 'async global helper method can use args' do
    ex = AsyncExample.create!
    async(ex).method_with_args_spread_args_and_kwargs(1, 2, 3, 4)
    run_last

    assert_equal ex.reload.testfield, '[2, 3, 4]'
  end
end
