# frozen_string_literal: true

module RailsAsyncMethods
  module TestHelper
    def assert_async_method_enqueued(target, method_name, args: [], kwargs: {}, job: nil, queue: nil, at: nil, &block)
      expected_target = target.is_a?(Class) ? ClassTarget.new(class_name: target.name) : target
      expected_job = job || RailsAsyncMethods.configuration.default_job_class.constantize

      options = {
        job: expected_job,
        args: [expected_target, method_name.to_s, args, kwargs]
      }
      options[:queue] = queue if queue
      options[:at] = at if at

      assert_enqueued_with(**options, &block)
    end
  end
end
