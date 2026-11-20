# frozen_string_literal: true

module RailsAsyncMethods
  class Configuration
    attr_reader :default_job_class
    attr_accessor :enqueue_after_transaction_commit

    def initialize
      @default_job_class = "RailsAsyncMethods::DispatchJob"
      @enqueue_after_transaction_commit = default_transaction_commit_setting
    end

    def default_job_class=(value)
      @default_job_class = Invocation.normalize_job_name!(value)
    end

    private

    def default_transaction_commit_setting
      if ActiveJob.respond_to?(:gem_version) && ActiveJob.gem_version >= Gem::Version.new("8.0.0.alpha")
        true
      else
        :always
      end
    end
  end
end
