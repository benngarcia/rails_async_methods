# frozen_string_literal: true

module RailsAsyncMethods
  module Signature
    module_function

    def validate!(method_obj, args, kwargs)
      params = method_obj.parameters
      min_pos = 0
      opt_pos = 0
      has_rest = false
      req_keys = []
      opt_keys = []
      has_keyrest = false
      has_nokey = false

      params.each do |type, name|
        case type
        when :req     then min_pos += 1
        when :opt     then opt_pos += 1
        when :rest    then has_rest = true
        when :keyreq  then req_keys << name
        when :key     then opt_keys << name
        when :keyrest then has_keyrest = true
        when :nokey   then has_nokey = true
        end
      end

      accepts_keywords = !req_keys.empty? || !opt_keys.empty? || has_keyrest

      norm_args = args.dup
      norm_kwargs = kwargs.dup

      if has_nokey && !norm_kwargs.empty?
        raise ArgumentError, "no keywords accepted"
      end

      if !accepts_keywords && !has_nokey && !norm_kwargs.empty?
        norm_args << norm_kwargs
        norm_kwargs = {}
      end

      max_pos = has_rest ? Float::INFINITY : (min_pos + opt_pos)
      if norm_args.length < min_pos || norm_args.length > max_pos
        expected = format_expected_arity(min_pos, max_pos)
        raise ArgumentError, "wrong number of arguments (given #{norm_args.length}, expected #{expected})"
      end

      if accepts_keywords
        missing = req_keys - norm_kwargs.keys
        unless missing.empty?
          label = missing.size == 1 ? "missing keyword" : "missing keywords"
          raise ArgumentError, "#{label}: #{missing.map(&:inspect).join(', ')}"
        end

        unless has_keyrest
          allowed = req_keys + opt_keys
          unknown = norm_kwargs.keys - allowed
          unless unknown.empty?
            label = unknown.size == 1 ? "unknown keyword" : "unknown keywords"
            raise ArgumentError, "#{label}: #{unknown.map(&:inspect).join(', ')}"
          end
        end
      end

      [norm_args, norm_kwargs]
    end

    def format_expected_arity(min_pos, max_pos)
      return "#{min_pos}+" if max_pos == Float::INFINITY
      return min_pos.to_s if min_pos == max_pos

      "#{min_pos}..#{max_pos}"
    end
  end
end
