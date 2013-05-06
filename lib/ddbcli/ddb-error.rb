module DynamoDB
  class Error < StandardError
    attr_reader :data

    def initialize(error_message, data = {})
      super(error_message)
      @data = data
    end
  end
end
