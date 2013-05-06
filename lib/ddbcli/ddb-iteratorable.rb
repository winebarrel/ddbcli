module DynamoDB
  class Iteratorable
    attr_reader :data
    attr_reader :last_evaluated_key

    def initialize(data, last_evaluated_key)
      @data = data
      @last_evaluated_key = last_evaluated_key
    end
  end
end
