require "rails_async_methods/version"

module RailsAsyncMethods
  autoload :AsyncMethod, 'rails_async_methods/async_method'
end

ActiveSupport.on_load(:active_record) do
  include RailsAsyncMethods::AsyncMethod
end
