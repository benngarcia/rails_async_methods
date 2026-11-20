# frozen_string_literal: true

module RailsAsyncMethods
  module Invocation
    VALID_OPTION_KEYS = %i[queue wait wait_until priority job].freeze

    module_function

    def validate_declaration_options!(options)
      validate_common_options!(options)

      if options.key?(:wait_until) && !options[:wait_until].nil? && !options[:wait_until].respond_to?(:call)
        raise InvalidOptionError,
              "wait_until on async_method declarations must be a Proc/lambda (evaluated at enqueue time), " \
              "got #{options[:wait_until].class}"
      end

      normalized = options.dup
      if normalized.key?(:job) && !normalized[:job].nil?
        normalized[:job] = normalize_job_name!(normalized[:job])
      end
      normalized.freeze
    end

    def validate_call_options!(options)
      validate_common_options!(options)

      normalized = options.dup
      if normalized.key?(:job) && !normalized[:job].nil?
        normalized[:job] = normalize_job_name!(normalized[:job])
      end
      normalized
    end

    def normalize_job_name!(value)
      case value
      when String
        raise InvalidJobClassError, "job class name cannot be blank" if value.strip.empty?

        value
      when Symbol
        value.to_s
      when Class
        raise InvalidJobClassError, "anonymous job classes cannot be serialized across processes" if value.name.nil?
        unless value < ActiveJob::Base
          raise InvalidJobClassError, "#{value.name} must inherit from ActiveJob::Base"
        end

        value.name
      else
        raise InvalidJobClassError, "job must be an ActiveJob::Base subclass, String, or Symbol, got #{value.class}"
      end
    end

    def dispatch(target:, scope:, call_options:, enqueue:, method_name:, args:, kwargs:, block:)
      if block
        raise ArgumentError, "Cannot pass a block to async method #{target_label(target, scope)}#{method_name}"
      end

      sym = method_name.to_sym
      declaration_options = fetch_declaration_options!(target, scope, sym)

      unless target.respond_to?(sym, false)
        raise NoMethodError, "undefined or non-public method '#{sym}' for #{target.inspect}"
      end

      serialized_target = serialize_target!(target, scope, sym)
      norm_args, norm_kwargs = Signature.validate!(target.method(sym), args, kwargs)
      resolved_job_class, set_options = resolve_job_and_options!(target, declaration_options, call_options)

      payload = [serialized_target, sym.to_s, norm_args, norm_kwargs]
      if enqueue
        resolved_job_class.set(**set_options).perform_later(*payload)
      else
        resolved_job_class.new(*payload).set(**set_options)
      end
    end

    def respond_to?(target, scope, method_name)
      sym = method_name.to_sym
      registry = scope == :class ? target._async_class_methods : target.class._async_instance_methods
      registry.key?(sym) && target.respond_to?(sym, false)
    end

    def validate_common_options!(options)
      options.assert_valid_keys(*VALID_OPTION_KEYS)

      if !options[:wait].nil? && !options[:wait_until].nil?
        raise InvalidOptionError, "Cannot specify both :wait and :wait_until"
      end

      if options.key?(:priority) && !options[:priority].nil?
        val = options[:priority]
        unless val.is_a?(Integer) || val.respond_to?(:call)
          raise InvalidOptionError, "priority must be an Integer or Proc, got #{val.class}"
        end
      end
    end

    def fetch_declaration_options!(target, scope, sym)
      registry = scope == :class ? target._async_class_methods : target.class._async_instance_methods
      return registry[sym] if registry.key?(sym)

      hint = scope == :class ? "async_class_method :#{sym}" : "async_method :#{sym}"
      raise UnauthorizedMethodError,
            "#{target_label(target, scope)}#{sym} is not declared async (add `#{hint}`)"
    end

    def serialize_target!(target, scope, sym)
      if scope == :class
        if target.name.nil?
          raise UnserializableTargetError, "Cannot dispatch async class method '#{sym}' on an anonymous class"
        end

        ClassTarget.new(class_name: target.name)
      else
        unless target.is_a?(GlobalID::Identification)
          raise UnserializableTargetError,
                "#{target.class} must include GlobalID::Identification for instance async methods " \
                "(or use `async_class_method` for stateless classes)"
        end

        if target.respond_to?(:persisted?) && !target.persisted?
          raise UnpersistedTargetError,
                "Cannot dispatch async method '#{sym}' on unpersisted #{target.class} instance"
        end

        target
      end
    end

    def resolve_job_and_options!(target, declaration_options, call_options)
      validated_call = validate_call_options!(call_options)
      merged = declaration_options.merge(validated_call)

      # Call-site :wait overrides declaration :wait_until (and vice versa)
      merged.delete(:wait_until) if validated_call.key?(:wait) && !validated_call[:wait].nil?
      merged.delete(:wait) if validated_call.key?(:wait_until) && !validated_call[:wait_until].nil?

      job_name = merged.delete(:job) || RailsAsyncMethods.configuration.default_job_class
      job_class = resolve_job_class!(job_name)

      set_options = {}
      merged.each do |key, value|
        next if value.nil?

        evaluated = value.respond_to?(:call) ? evaluate_callable(value, target) : value
        next if evaluated.nil?

        if key == :priority && !evaluated.is_a?(Integer)
          raise InvalidOptionError, "priority must evaluate to an Integer, got #{evaluated.class}"
        end

        set_options[key] = evaluated
      end

      [job_class, set_options]
    end

    def resolve_job_class!(job_name)
      klass = job_name.safe_constantize
      unless klass.is_a?(Class) && klass < ActiveJob::Base
        raise InvalidJobClassError, "#{job_name.inspect} is not a loaded ActiveJob::Base subclass"
      end

      klass
    end

    def evaluate_callable(callable, target)
      callable.arity == 0 ? callable.call : callable.call(target)
    end

    def target_label(target, scope)
      scope == :class ? "#{target.name || '<AnonymousClass>'}." : "#{target.class.name || '<AnonymousClass>'}#"
    end
  end
end
