require 'base64'

module DynamoDB
  class Binary
    def initialize(value)
      @value = value
    end

    def value
      Base64.encode64(@value).delete("\n")
    end

    alias to_s value
    alias to_str value

    def inspect
      @value.inspect
    end
  end
end
