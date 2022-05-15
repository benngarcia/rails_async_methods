require 'rails_async_methods/wrapper/async_wrapper'

module RailsAsyncMethods
  module AsyncJobs
    def async(receiver, options = {})
      receiver.to_active_job options
    end
  end
end