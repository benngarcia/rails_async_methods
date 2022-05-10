require "test_helper"
require 'pry'
class AsyncMethodRailsTest < ActiveSupport::TestCase
  include DelayedJobRunner

  test "it has a version number" do
    assert AsyncMethodRails::VERSION
  end

  test "it generates the abstract job" do
    system "cd test/dummy && rails generate async_method_rails"
    assert File.exist? "test/dummy/app/jobs/async_method_rails/abstract_job.rb"
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
    assert_raises(AsyncMethodRails::AsyncMethod::NotPersistedError) { ex.async_set_testfield_nil }
  end

  test "it does not accept a block" do
    ex = AsyncExample.create!
    # flunk { "block_given? gets confused about which context to check for block" }
  end

  test "it can correctly work with spread args and kwargs" do
    ex = AsyncExample.create!
    ex.async_method_with_args_spread_args_and_kwargs(1, 2, 3, **{:foo => :bar})
    run_last
    assert_equal ex.reload.testfield, "[2, 3]"
  end
end
