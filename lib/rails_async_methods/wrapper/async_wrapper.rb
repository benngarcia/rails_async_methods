require 'rails_async_methods/active_job_options_parser'

module RailsAsyncMethods
  class AsyncWrapper
    class NotPersistedError < StandardError; end
    attr_reader :receiver, :options

    def initialize(receiver, options = {})
      @receiver = receiver
      @options = RailsAsyncMethods::ActiveJobOptionsParser.new(options)
    end

    def method_missing(method, *args, **kwargs)
      raise NotPersistedError, 'Instance must be persisted to run asynchronously' unless receiver.persisted?
      raise TypeError, 'Cannot pass a block to an asynchronous method' if block_given?

      if @receiver.methods.include? method
        @options.job.set(**@options.to_h).perform_later(@receiver, method, *args, **kwargs)
      else
        super
      end
    end

    def respond_to_missing?(method)
      @receiver.methods.include?(method) || super
    end
  end
end