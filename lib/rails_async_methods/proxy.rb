# frozen_string_literal: true

module RailsAsyncMethods
  class Proxy < ::BasicObject
    undef_method :instance_eval, :instance_exec

    def initialize(target, scope:, options:, enqueue:)
      @target = target
      @scope = scope
      @options = options
      @enqueue = enqueue
    end

    def method_missing(method_name, *args, **kwargs, &block)
      ::RailsAsyncMethods::Invocation.dispatch(
        target: @target,
        scope: @scope,
        call_options: @options,
        enqueue: @enqueue,
        method_name: method_name,
        args: args,
        kwargs: kwargs,
        block: block
      )
    end

    def respond_to?(method_name, include_private = false)
      respond_to_missing?(method_name, include_private)
    end

    def respond_to_missing?(method_name, _include_private = false)
      ::RailsAsyncMethods::Invocation.respond_to?(@target, @scope, method_name)
    end
  end
end
