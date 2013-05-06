module DynamoDB
  class Binary
    attr_reader :value
    alias to_s value
    alias to_str value

    def initialize(value)
      @value = value
    end

    def inspect
      @value.inspect
    end
  end
end
