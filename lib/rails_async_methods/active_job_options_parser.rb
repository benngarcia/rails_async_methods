module RailsAsyncMethods
  class ActiveJobOptionsParser
    SET_OPTIONS = %i[queue wait_until wait priority].freeze

    attr_reader :prefix, :queue, :wait_until, :wait, :priority, :job
    STRING_ARG_SEPERATOR = [':', ','].freeze

    def initialize(opts={})
      @prefix = method_prefix(opts[:prefix])
      @queue = opts[:queue]
      @wait_until = opts[:wait_until].to_f if opts[:wait_until]
      @wait = opts[:wait].seconds.to_f if opts[:wait]
      @priority = opts[:priority].to_i if opts[:priority]
      @job = get_job_obj(opts[:job])
    end

    def to_h
      valid_instance_values
    end

    def to_s
      return '' if valid_instance_values.empty?

      valid_instance_values.to_s
    end

    private

    def valid_instance_values
      Hash[SET_OPTIONS.filter_map { |name| [name, send(name)] unless send(name).nil? }]
    end

    def method_prefix(prefix)
      return 'async_' if prefix.nil? || prefix.empty?

      (prefix.is_a? Symbol) ? prefix.to_s : prefix
    end

    def get_job_obj(job)
      return RailsAsyncMethods::AbstractJob if job.nil?

      (job.is_a? Symbol) ? Object.const_get(job) : job
    end
  end
end