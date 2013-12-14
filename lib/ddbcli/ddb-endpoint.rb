require 'ddbcli/ddb-error'

module DynamoDB
  class Endpoint

    ENDPOINTS = {
      'dynamodb.us-east-1.amazonaws.com'      => 'us-east-1',
      'dynamodb.us-west-1.amazonaws.com'      => 'us-west-1',
      'dynamodb.us-west-2.amazonaws.com'      => 'us-west-2',
      'dynamodb.eu-west-1.amazonaws.com'      => 'eu-west-1',
      'dynamodb.ap-northeast-1.amazonaws.com' => 'ap-northeast-1',
      'dynamodb.ap-southeast-1.amazonaws.com' => 'ap-southeast-1',
      'dynamodb.ap-southeast-2.amazonaws.com' => 'ap-southeast-2',
      'dynamodb.sa-east-1.amazonaws.com'      => 'sa-east-1',
    }

    def self.endpoint_and_region(endpoint_or_region)
      if ENDPOINTS.key?(endpoint_or_region)
        [endpoint_or_region, ENDPOINTS[endpoint_or_region]]
      elsif ENDPOINTS.value?(endpoint_or_region)
        ep_key = ENDPOINTS.respond_to?(:key) ? ENDPOINTS.key(endpoint_or_region) : ENDPOINTS.index(endpoint_or_region)
        [ep_key, endpoint_or_region]
      else
        raise DynamoDB::Error, 'Unknown endpoint or region'
      end
    end

    def self.regions
      ENDPOINTS.values.dup
    end
  end # Endpoint
end # DynamoDB
