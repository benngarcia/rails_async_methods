require 'rails_async_methods/wrapper/async_wrapper'
require 'rails_async_methods/wrapper/async_jobs'

class Object
  include RailsAsyncMethods::AsyncJobs

  def to_active_job(options = {})
    RailsAsyncMethods::AsyncWrapper.new(self, options)
  end
end