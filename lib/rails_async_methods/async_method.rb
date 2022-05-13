require 'rails_async_methods/parameter_parser'
require 'rails_async_methods/active_job_options_parser'

module RailsAsyncMethods
  module AsyncMethod
    extend ActiveSupport::Concern

    class NotPersistedError < StandardError; end

    class_methods do
      # Supported Options
      # wait: Pass Date
      def async(method_name, opts={})
        raise NoMethodError unless method_defined?(method_name)
        unbound_method = instance_method(method_name.to_sym)

        parsed_method_arguments = RailsAsyncMethods::ParameterParser.new(unbound_method.parameters)
        active_job_arguments = RailsAsyncMethods::ActiveJobOptionsParser.new(opts)

        if parsed_method_arguments.empty?
          define_method "#{active_job_arguments.prefix.concat(method_name.to_s)}" do
            raise NotPersistedError, 'Instance must be persisted to run asynchronously' unless persisted?
            raise TypeError, 'Cannot pass a block to an asynchronous method' if block_given?

            active_job_arguments.job.set(**active_job_arguments.to_h).perform_later(self, method_name)
          end
        else
          stringified_method_body = begin
            <<~RUBY
              define_method "#{active_job_arguments.prefix.concat(method_name.to_s)}" do |#{parsed_method_arguments.as_argument_string}|
                raise NotPersistedError, "Instance must be persisted to run asynchronously" unless persisted?
                raise TypeError, "Cannot pass a block to an asynchronous methods" if block_given?

                positional_args, keyword_args = parsed_method_arguments.arg_values_for_job { |argument| binding.local_variable_get(argument) }
                #{active_job_arguments.job}
                  .set(#{active_job_arguments})
                  .perform_later(self, method_name, *positional_args, **keyword_args)
              end
            RUBY
          end
          module_eval stringified_method_body, *unbound_method.source_location
        end
      end
    end
  end
end