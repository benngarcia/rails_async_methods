require "rails_async_methods/version"
require "rails_async_methods/core_ext"

warn "[rails_async_methods] DEPRECATED: This gem is sunset and no longer maintained. " \
     "See https://github.com/benngarcia/rails_async_methods and the security-hardened " \
     "reference implementation at https://github.com/benngarcia/rails_async_methods/tree/rewrite"

module RailsAsyncMethods
  autoload :AsyncMethod, 'rails_async_methods/async_method'
  autoload :AsyncWrapper, 'rails_async_methods/wrapper/async_wrapper'
  autoload :AsyncJobs, 'rails_async_methods/wrapper/async_jobs'
end

ActiveSupport.on_load(:active_record) do
  include RailsAsyncMethods::AsyncMethod
end
