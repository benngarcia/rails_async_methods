# frozen_string_literal: true

module RailsAsyncMethods
  module Concern
    extend ActiveSupport::Concern

    included do
      class_attribute :_async_instance_methods, instance_writer: false, default: {}.freeze
      class_attribute :_async_class_methods, instance_writer: false, default: {}.freeze
    end

    class_methods do
      def async_method(method_name, **options)
        name = normalize_async_method_name!(method_name)
        validated = Invocation.validate_declaration_options!(options)
        self._async_instance_methods = _async_instance_methods.merge(name => validated).freeze
        method_name
      end

      def async_class_method(method_name, **options)
        name = normalize_async_method_name!(method_name)
        validated = Invocation.validate_declaration_options!(options)
        self._async_class_methods = _async_class_methods.merge(name => validated).freeze
        method_name
      end

      def async(**options)
        Proxy.new(self, scope: :class, options: options, enqueue: true)
      end

      def async_job(**options)
        Proxy.new(self, scope: :class, options: options, enqueue: false)
      end

      private

      def normalize_async_method_name!(method_name)
        unless method_name.is_a?(Symbol) || (method_name.is_a?(String) && !method_name.empty?)
          raise ArgumentError, "method_name must be a Symbol or non-empty String, got #{method_name.inspect}"
        end

        method_name.to_sym
      end
    end

    def async(**options)
      Proxy.new(self, scope: :instance, options: options, enqueue: true)
    end

    def async_job(**options)
      Proxy.new(self, scope: :instance, options: options, enqueue: false)
    end
  end
end
