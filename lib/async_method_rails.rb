require "async_method_rails/version"

module AsyncMethodRails
  autoload :AsyncMethod, 'async_method_rails/async_method'
end

ActiveSupport.on_load(:active_record) do
  include AsyncMethodRails::AsyncMethod
end
