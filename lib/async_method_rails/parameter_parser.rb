module AsyncMethodRails
  class ParameterParser
    REQ_POS_DELIMETER = ','.freeze
    OPT_POS_DELIMETER = '=nil,'.freeze
    REST_POS_DELIMETER = ['*', ','].freeze
    REQ_KEY_DELIMETER = ':,'.freeze
    OPT_KEY_DELIMETER = ':nil,'.freeze
    REST_KEY_DELIMETER = ['**', ','].freeze
    BLOCK_DELIMETER = '&'.freeze
    attr_reader :parameters

    def initialize(parameters)
      @parameters = parameters
    end

    def empty?
      parameters.empty?
    end

    def as_argument_string
      return '' if @parameters.empty?

      parameters.map { |type, name| to_argument_string(type, name)}.join.chomp(',')
    end

    def arg_values_for_job(&block)
      final_arg_values = [[], {}]
      @parameters.each do |type, name|
        case type
        when :req, :opt, :rest
          final_arg_values[0].append(block.call(name))
        when :keyreq, :key, :keyrest
          final_arg_values[1].merge!(name => block.call(name))
        end
      end
      final_arg_values
    end

    private

    def to_argument_string(type, name)
      case type
      when :req
        name.to_s.concat(REQ_POS_DELIMETER)
      when :opt
        name.to_s.concat(OPT_POS_DELIMETER)
      when :keyreq
        name.to_s.concat(REQ_KEY_DELIMETER)
      when :key
        name.to_s.concat(OPT_KEY_DELIMETER)
      when :rest
        name.to_s.prepend(REST_POS_DELIMETER[0]).concat(REST_POS_DELIMETER[1])
      when :keyrest
        name.to_s.prepend(REST_KEY_DELIMETER[0]).concat(REST_KEY_DELIMETER[1])
      when :block
        name.to_s.prepend(BLOCK_DELIMETER)
      end
    end
  end
end