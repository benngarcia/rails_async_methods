# frozen_string_literal: true

require "active_support"
require "active_support/concern"
require "active_support/core_ext/class/attribute"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/string/inflections"
require "active_support/duration"
require "active_support/lazy_load_hooks"
require "active_support/notifications"
require "active_job"
require "global_id"

require_relative "rails_async_methods/version"
require_relative "rails_async_methods/configuration"
require_relative "rails_async_methods/signature"
require_relative "rails_async_methods/invocation"
require_relative "rails_async_methods/proxy"
require_relative "rails_async_methods/concern"

module RailsAsyncMethods
  class Error < StandardError; end
  class UnauthorizedMethodError < Error; end
  class UnpersistedTargetError < Error; end
  class UnserializableTargetError < Error; end
  class InvalidJobClassError < Error; end
  class InvalidOptionError < Error; end

  autoload :TestHelper, File.expand_path("rails_async_methods/test_helper", __dir__)

  extend ActiveSupport::Concern
  include Concern

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def allowed_method?(target, method_name)
      sym = method_name.to_sym
      if target.is_a?(Class)
        target.include?(RailsAsyncMethods) && target._async_class_methods.key?(sym)
      else
        target.is_a?(RailsAsyncMethods) && target.class._async_instance_methods.key?(sym)
      end
    end

    def register_serializers!
      return if ActiveJob::Serializers.serializers.include?(ClassTargetSerializer)

      ActiveJob::Serializers.add_serializers(ClassTargetSerializer)
    end
  end
end

require_relative "rails_async_methods/dispatch_job"
require_relative "rails_async_methods/railtie" if defined?(Rails::Railtie)

ActiveSupport.on_load(:active_job) do
  RailsAsyncMethods.register_serializers!
end
RailsAsyncMethods.register_serializers!
