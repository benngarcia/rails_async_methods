# frozen_string_literal: true

module RailsAsyncMethods
  ClassTarget = Data.define(:class_name) do
    def resolve
      klass = class_name.safe_constantize
      unless klass.is_a?(Class)
        raise UnserializableTargetError, "Could not resolve async target class #{class_name.inspect}"
      end

      klass
    end
  end

  class ClassTargetSerializer < ActiveJob::Serializers::ObjectSerializer
    def serialize(target)
      super("class_name" => target.class_name)
    end

    def deserialize(hash)
      ClassTarget.new(class_name: hash.fetch("class_name"))
    end

    def klass
      ClassTarget
    end
  end

  module Dispatcher
    extend ActiveSupport::Concern

    included do
      if respond_to?(:enqueue_after_transaction_commit=)
        self.enqueue_after_transaction_commit = RailsAsyncMethods.configuration.enqueue_after_transaction_commit
      end
    end

    def perform(target, method_name, args = [], kwargs = {})
      resolved = target.is_a?(ClassTarget) ? target.resolve : target
      sym = method_name.to_sym

      unless RailsAsyncMethods.allowed_method?(resolved, sym)
        raise UnauthorizedMethodError,
              "Refused to perform undeclared async method '#{sym}' on #{resolved.inspect}"
      end

      symbolized_kwargs = kwargs.empty? ? {} : kwargs.symbolize_keys

      ActiveSupport::Notifications.instrument(
        "perform.rails_async_methods",
        target: resolved,
        method: sym,
        job: self.class.name
      ) do
        if symbolized_kwargs.empty?
          resolved.public_send(sym, *args)
        else
          resolved.public_send(sym, *args, **symbolized_kwargs)
        end
      end
    end
  end

  class DispatchJob < ActiveJob::Base
    include Dispatcher
  end
end
