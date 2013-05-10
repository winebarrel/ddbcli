require 'optparse'
require 'ostruct'

def parse_options
  options = OpenStruct.new
  options.access_key_id     = ENV['AWS_ACCESS_KEY_ID']
  options.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  options.ddb_endpoint_or_region =
    ENV['DDB_ENDPOINT'] || ENV['DDB_REGION'] || 'dynamodb.us-east-1.amazonaws.com'

  # default value
  options.timeout     = 60
  options.consistent  = false
  options.iteratable  = false
  options.retry_num   = 3
  options.retry_intvl = 10
  options.debug       = false

  ARGV.options do |opt|
    opt.on('-k', '--access-key=ACCESS_KEY')          {|v| options.access_key_id          = v      }
    opt.on('-s', '--secret-key=SECRET_KEY')          {|v| options.secret_access_key      = v      }
    opt.on('-r', '--region=REGION_OR_ENDPOINT')      {|v| options.ddb_endpoint_or_region = v      }
    opt.on('-e', '--eval=COMMAND')                   {|v| options.command                = v      }
    opt.on('-t', '--timeout=SECOND', Integer)        {|v| options.timeout                = v.to_i }
    opt.on('',   '--consistent-read')                {    options.consistent             = true   }
    opt.on('',   '--iteratable')                     {    options.iteratable             = true   }
    opt.on('',   '--retry=NUM', Integer)             {|v| options.retry_num              = v.to_i }
    opt.on('',   '--retry-interval=SECOND', Integer) {|v| options.retry_intvl            = v.to_i }
    opt.on('',   '--debug')                          {    options.debug                  = true   }

    opt.on('-h', '--help') {
      puts opt.help
      puts
      print_help
      exit
    }

    opt.parse!

    unless options.access_key_id and options.secret_access_key and options.ddb_endpoint_or_region
      puts opt.help
      exit 1
    end
  end

  options
end
