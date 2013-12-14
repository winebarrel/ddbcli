require 'ddbcli/ddb-client'
require 'ddbcli/ddb-parser.tab'
require 'ddbcli/ddb-iteratorable'

require 'forwardable'
require 'strscan'

module DynamoDB
  class Driver
    extend Forwardable

    MAX_NUMBER_BATCH_PROCESS_ITEMS = 25

    class Rownum
      def initialize(rownum)
        @rownum = rownum
      end

      def to_i
        @rownum
      end
    end # Rownum

    def initialize(accessKeyId, secretAccessKey, endpoint_or_region)
      @client = DynamoDB::Client.new(accessKeyId, secretAccessKey, endpoint_or_region)
      @consistent = false
      @iteratable = false
    end

    def_delegators(
      :@client,
      :endpoint,
      :region,
      :timeout, :'timeout=',
      :set_endpoint_and_region,
      :retry_num, :'retry_num=',
      :retry_intvl, :'retry_intvl=',
      :debug, :'debug=')

    attr_accessor :consistent
    attr_accessor :iteratable

    def execute(query, opts = {})
      parsed, script_type, script = Parser.parse(query)
      command = parsed.class.name.split('::').last.to_sym

      if command != :NEXT
        @last_action = nil
        @last_parsed = nil
        @last_evaluated_key = nil
      end

      retval = case command
               when :SHOW_TABLES
                 do_show_tables(parsed)
               when :SHOW_TABLE_STATUS
                 do_show_table_status(parsed)
               when :SHOW_REGIONS
                 do_show_regions(parsed)
               when :SHOW_CREATE_TABLE
                 do_show_create_table(parsed)
               when :ALTER_TABLE
                 do_alter_table(parsed)
               when :USE
                 do_use(parsed)
               when :CREATE
                 do_create(parsed)
               when :CREATE_LIKE
                 do_create_like(parsed)
               when :DROP
                 do_drop(parsed)
               when :DESCRIBE
                 do_describe(parsed)
               when :SELECT
                 do_select('Query', parsed)
               when :SCAN
                 do_select('Scan', parsed)
               when :GET
                 do_get(parsed)
               when :UPDATE
                 do_update(parsed)
               when :UPDATE_ALL
                 do_update_all(parsed)
               when :DELETE
                 do_delete(parsed)
               when :DELETE_ALL
                 do_delete_all(parsed)
               when :INSERT
                 do_insert(parsed)
               when :INSERT_SELECT
                 do_insert_select('Query', parsed)
               when :INSERT_SCAN
                 do_insert_select('Scan', parsed)
               when :NEXT
                 if @last_action and @last_parsed and @last_evaluated_key
                   do_select(@last_action, @last_parsed, :last_evaluated_key => @last_evaluated_key)
                 else
                   []
                 end
               when :NULL
                 nil
               else
                 raise 'must not happen'
               end

      begin
        case script_type
        when :ruby
          retval = retval.data if retval.kind_of?(DynamoDB::Iteratorable)
          retval.instance_eval(script)
        when :shell
          retval = retval.data if retval.kind_of?(DynamoDB::Iteratorable)
          IO.popen(script, "r+") do |f|
            f.puts(retval.kind_of?(Array) ? retval.map {|i| i.to_s }.join("\n") : retval.to_s)
            f.close_write
            f.read
          end
        when :overwrite
          open(script, 'wb') {|f| print_json(retval, f, opts.merge(:show_rows => false, :strip => true)) }
          retval = nil
        when :append
          open(script, 'ab') {|f| print_json(retval, f, opts.merge(:show_rows => false, :strip => true)) }
          retval = nil
        else
          retval
        end
      rescue Exception => e
        raise DynamoDB::Error, e.message, e.backtrace
      end
    end

    def import(table, items)
      n = 0

      until (chunk = items.slice!(0, MAX_NUMBER_BATCH_PROCESS_ITEMS)).empty?
        operations = []

        req_hash = {
          'RequestItems' => {
            table => operations,
          },
        }

        chunk.each do |item|
          h = {}

          operations << {
            'PutRequest' => {
              'Item' => h,
            },
          }

          item.each do |name, val|
            h[name] = convert_to_attribute_value(val)
          end
        end

        batch_write_item(req_hash)
        n += chunk.length
      end

      return n
    end

    private

    def do_show_tables(parsed)
      do_show_tables0(parsed.like, parsed.limit)
    end

    def do_show_tables0(like, limit = nil)
      like = like ? like_to_regexp(like) : nil
      req_hash = {}
      table_names = []

      req_hash['Limit'] = limit if limit

      list = lambda do |last_evaluated_table_name|
        req_hash['ExclusiveStartTableName'] = last_evaluated_table_name if last_evaluated_table_name
        res_data = @client.query('ListTables', req_hash)
        table_names.concat(res_data['TableNames'])
        req_hash['LastEvaluatedTableName']
      end

      letn = nil

      loop do
        letn = list.call(letn)

        if limit or not letn
          break
        end
      end

      return like ? table_names.select {|i| i =~ like } : table_names
    end

    def do_show_table_status(parsed)
      table_names = do_show_tables0(parsed.like)
      h = {}

      table_names.map do |table_name|
        table_info = @client.query('DescribeTable', 'TableName' => table_name)['Table']
        h[table_name] = {}

        %w(TableStatus ItemCount TableSizeBytes).each do |i|
          h[table_name][i] = table_info[i]
        end

        provisioned_throughput = table_info['ProvisionedThroughput']

        %w(ReadCapacityUnits WriteCapacityUnits).each do |i|
          h[table_name][i] = provisioned_throughput[i]
        end
      end

      return h
    end

    def do_show_regions(parsed)
      DynamoDB::Endpoint.regions
    end

    def do_show_create_table(parsed)
      table_info = @client.query('DescribeTable', 'TableName' => parsed.table)['Table']
      table_name = table_info['TableName']

      attr_types = {}
      table_info['AttributeDefinitions'].each do |i|
        name = i['AttributeName']
        attr_types[name] = {
          'S' => 'STRING',
          'N' => 'NUMBER',
          'B' => 'BINARY',
        }.fetch(i['AttributeType'])
      end

      key_schema = {}
      table_info['KeySchema'].map do |i|
        name = i['AttributeName']
        key_type = i['KeyType']
        key_schema[name] = key_type
      end

      indexes = {}

      (table_info['LocalSecondaryIndexes'] || []).each do |i|
        index_name = i['IndexName']
        key_name = i['KeySchema'].find {|j| j['KeyType'] == 'RANGE' }['AttributeName']
        proj_type = i['Projection']['ProjectionType']
        proj_attrs = i['Projection']['NonKeyAttributes']
        indexes[index_name] = [key_name, proj_type, proj_attrs]
      end

      global_indexes = {}

      (table_info['GlobalSecondaryIndexes'] || []).each do |i|
        index_name = i['IndexName']
        key_names = i['KeySchema'].map {|j| j['AttributeName'] }
        proj_type = i['Projection']['ProjectionType']
        proj_attrs = i['Projection']['NonKeyAttributes']

        idx_throughput = i['ProvisionedThroughput']
        idx_throughput = {
          :read  => idx_throughput['ReadCapacityUnits'],
          :write => idx_throughput['WriteCapacityUnits'],
        }

        global_indexes[index_name] = [key_names, proj_type, proj_attrs, idx_throughput]
      end

      throughput = table_info['ProvisionedThroughput']
      throughput = {
        :read  => throughput['ReadCapacityUnits'],
        :write => throughput['WriteCapacityUnits'],
      }

      quote = lambda {|i| '`' + i.gsub('`', '``') + '`' } # `

      buf = "CREATE TABLE #{quote[table_name]} ("

      buf << "\n  " + key_schema.map {|name, key_type|
        attr_type = attr_types[name]
        "#{quote[name]} #{attr_type} #{key_type}"
      }.join(",\n  ")

      unless indexes.empty?
        buf << ",\n  " + indexes.map {|index_name, key_name_proj|
          key_name, proj_type, proj_attrs = key_name_proj
          attr_type = attr_types[key_name]
          index_clause = "INDEX #{quote[index_name]} (#{quote[key_name]} #{attr_type}) #{proj_type}"
          index_clause << " (#{proj_attrs.join(', ')})" if proj_attrs
          index_clause
        }.join(",\n  ")
      end

      unless global_indexes.empty?
        buf << ",\n  " + global_indexes.map {|index_name, key_names_proj_itp|
          key_names, proj_type, proj_attrs, idx_throughput = key_names_proj_itp
          index_clause = "GLOBAL INDEX #{quote[index_name]} ("

          index_clause << key_names.map {|key_name|
            attr_type = attr_types[key_name]
            "#{quote[key_name]} #{attr_type}"
          }.join(', ')

          index_clause << ") #{proj_type}"
          index_clause << " (#{proj_attrs.join(', ')})" if proj_attrs
          index_clause << ' ' + idx_throughput.map {|k, v| "#{k}=#{v}" }.join(' ')
          index_clause
        }.join(",\n  ")
      end

      buf << "\n)"
      buf << ' ' + throughput.map {|k, v| "#{k}=#{v}" }.join(' ')
      buf << "\n\n"

      return buf
    end

    def do_alter_table(parsed)
      req_hash = {
        'TableName' => parsed.table,
        'ProvisionedThroughput' => {
          'ReadCapacityUnits'  => parsed.capacity[:read],
          'WriteCapacityUnits' => parsed.capacity[:write],
        },
      }

      @client.query('UpdateTable', req_hash)
      nil
    end

    def do_use(parsed)
      eor = parsed.endpoint_or_region

      if %r|\A\w+://| =~ eor or /:\d+\Z/ =~ eor
        eor = "http://#{eor}" unless eor =~ %r|\A\w+://|
        eor = URI.parse(eor)

        unless /\Ahttps?\Z/ =~ eor.scheme
          raise URI::InvalidURIError, "invalid shceme: #{parsed.endpoint_or_region}"
        end
      end

      set_endpoint_and_region(eor)
      nil
    end

    def do_create(parsed)
      req_hash = {
        'TableName' => parsed.table,
        'ProvisionedThroughput' => {
          'ReadCapacityUnits'  => parsed.capacity[:read],
          'WriteCapacityUnits' => parsed.capacity[:write],
        },
      }

      # hash key
      req_hash['AttributeDefinitions'] = [
        {
          'AttributeName' => parsed.hash[:name],
          'AttributeType' => parsed.hash[:type],
        }
      ]

      req_hash['KeySchema'] = [
        {
          'AttributeName' => parsed.hash[:name],
          'KeyType'       => 'HASH',
        }
      ]

      # range key
      if parsed.range
        req_hash['AttributeDefinitions'] << {
          'AttributeName' => parsed.range[:name],
          'AttributeType' => parsed.range[:type],
        }

        req_hash['KeySchema'] << {
          'AttributeName' => parsed.range[:name],
          'KeyType'       => 'RANGE',
        }
      end

      # secondary index
      local_indices = (parsed.indices || []).select {|i| not i[:global] }
      global_indices = (parsed.indices || []).select {|i| i[:global] }

      define_attribute = lambda do |attr_name, attr_type|
        attr_defs = req_hash['AttributeDefinitions']
        same_attr = attr_defs.find {|i| i['AttributeName'] == attr_name }

        if same_attr
          if same_attr['AttributeType'] != attr_type
            raise DynamoDB::Error, "different types have been defined: #{attr_name}"
          end
        else
          attr_defs << {
            'AttributeName' => attr_name,
            'AttributeType' => attr_type,
          }
        end
      end

      define_index = lambda do |idx_def, def_idx_opts|
        global_idx = def_idx_opts[:global]


        if global_idx
          idx_def[:keys].each do |key_type, name_type|
            define_attribute.call(name_type[:key], name_type[:type])
          end
        else
          define_attribute.call(idx_def[:key], idx_def[:type])
        end

        secondary_index = {
          'IndexName' => idx_def[:name],
          'Projection' => {
            'ProjectionType' => idx_def[:projection][:type],
          }
        }

        if global_idx
          secondary_index['KeySchema'] = []

          [:hash, :range].each do |key_type|
            name_type = idx_def[:keys][key_type]

            if name_type
              secondary_index['KeySchema'] << {
                'AttributeName' => name_type[:key],
                'KeyType'       => key_type.to_s.upcase,
              }
            end
          end
        else
          secondary_index['KeySchema'] = [
            {
              'AttributeName' => parsed.hash[:name],
              'KeyType'       => 'HASH',
            },
            {
              'AttributeName' => idx_def[:key],
              'KeyType'       => 'RANGE',
            },
          ]
        end

        if idx_def[:projection][:attrs]
          secondary_index['Projection']['NonKeyAttributes'] = idx_def[:projection][:attrs]
        end

        if global_idx
          capacity = idx_def[:capacity] || parsed.capacity

          secondary_index['ProvisionedThroughput'] = {
            'ReadCapacityUnits'  => capacity[:read],
            'WriteCapacityUnits' => capacity[:write],
          }
        end

        secondary_index
      end # define_index

      # local secondary index
      unless local_indices.empty?
        req_hash['LocalSecondaryIndexes'] = []

        local_indices.each do |idx_def|
          local_secondary_index = define_index.call(idx_def, :global => false)
          req_hash['LocalSecondaryIndexes'] << local_secondary_index
        end
      end

      # global secondary index
      unless global_indices.empty?
        req_hash['GlobalSecondaryIndexes'] = []

        global_indices.each do |idx_def|
          global_secondary_index = define_index.call(idx_def, :global => true)
          req_hash['GlobalSecondaryIndexes'] << global_secondary_index
        end
      end

      @client.query('CreateTable', req_hash)
      nil
    end

    def do_create_like(parsed)
      table_info = @client.query('DescribeTable', 'TableName' => parsed.like)['Table']

      req_hash = {
        'TableName'            => parsed.table,
        'AttributeDefinitions' => table_info['AttributeDefinitions'],
        'KeySchema'            => table_info['KeySchema'],
      }

      local_secondary_indexes = (table_info['LocalSecondaryIndexes'] || [])

      unless local_secondary_indexes.empty?
        req_hash['LocalSecondaryIndexes'] = local_secondary_indexes.map do |lsi|
          h = {}

          %w(IndexName KeySchema Projection).each do |i|
            h[i] = lsi[i]
          end

          h
        end
      end

      global_secondary_indexes = (table_info['GlobalSecondaryIndexes'] || [])

      unless global_secondary_indexes.empty?
        req_hash['GlobalSecondaryIndexes'] = global_secondary_indexes.map do |gsi|
          h = {}

          %w(IndexName KeySchema Projection).each do |i|
            h[i] = gsi[i]
          end

          h['ProvisionedThroughput'] = h_pt = {}

          %w(ReadCapacityUnits WriteCapacityUnits).each do |i|
            h_pt[i] = gsi['ProvisionedThroughput'][i]
          end

          h
        end
      end

      if parsed.capacity
        req_hash['ProvisionedThroughput'] = {
          'ReadCapacityUnits'  => parsed.capacity[:read],
          'WriteCapacityUnits' => parsed.capacity[:write],
        }
      else
        req_hash['ProvisionedThroughput'] = table_info['ProvisionedThroughput']
      end

      @client.query('CreateTable', req_hash)
      nil
    end

    def do_drop(parsed)
      @client.query('DeleteTable', 'TableName' => parsed.table)
      nil
    end

    def do_describe(parsed)
      (@client.query('DescribeTable', 'TableName' => parsed.table) || {}).fetch('Table', {})
    end

    def do_select(action, parsed, opts = {})
      do_select0(action, parsed, opts) do |i|
        convert_to_ruby_value(i)
      end
    end

    def do_select0(action, parsed, opts = {})
      select_proc = lambda do |last_evaluated_key|
        req_hash = {'TableName' => parsed.table}
        req_hash['AttributesToGet'] = parsed.attrs unless parsed.attrs.empty?
        req_hash['Limit'] = parsed.limit if parsed.limit
        req_hash['ExclusiveStartKey'] = last_evaluated_key if last_evaluated_key

        case action
        when 'Query'
          req_hash['ConsistentRead'] = @consistent if @consistent
          req_hash['IndexName'] = parsed.index if parsed.index
          req_hash['ScanIndexForward'] = parsed.order_asc unless parsed.order_asc.nil?
        when 'Scan'
          req_hash['Segment'] = parsed.segment if parsed.segment
          req_hash['TotalSegments'] = parsed.total_segments if parsed.total_segments
        end

        # XXX: req_hash['ReturnConsumedCapacity'] = ...

        if parsed.count
          req_hash['Select'] = 'COUNT'
        elsif not parsed.attrs.empty?
          req_hash['Select'] = 'SPECIFIC_ATTRIBUTES'
        end

        # key conditions / scan filter
        if parsed.conds
          param_name = (action == 'Query') ? 'KeyConditions' : 'ScanFilter'
          req_hash[param_name] = {}

          parsed.conds.each do |key, operator, values|
            h = req_hash[param_name][key] = {
              'ComparisonOperator' => operator.to_s
            }

            h['AttributeValueList'] = values.map do |val|
              convert_to_attribute_value(val)
            end
          end
        end # key conditions / scan filter

        rd = nil

        begin
          rd = @client.query(action, req_hash)
        rescue DynamoDB::Error => e
          if action == 'Query' and e.data['__type'] == 'com.amazon.coral.service#InternalFailure' and not (e.data['message'] || e.data['Message'])
            table_info = (@client.query('DescribeTable', 'TableName' => parsed.table) || {}).fetch('Table', {}) rescue {}

            unless table_info.fetch('KeySchema', []).any? {|i| i ||= {}; i['KeyType'] == 'RANGE' }
              e.message << 'Query can be performed only on a table with a HASH,RANGE key schema'
            end
          end

          raise e
        end

        rd
      end

      res_data = select_proc.call(opts[:last_evaluated_key])
      retval = nil

      if parsed.count
        retval = res_data['Count']

        while res_data['LastEvaluatedKey']
          res_data = select_proc.call(res_data['LastEvaluatedKey'])
          retval += res_data['Count']
        end
      else
        retval = block_given? ? res_data['Items'].map {|i| yield(i) } : res_data['Items']
        limit_orig = parsed.limit

        if @iteratable or opts[:iteratable] or (parsed.limit and retval.length < parsed.limit)
          parsed.limit -= retval.length if parsed.limit

          while res_data['LastEvaluatedKey']
            res_data = select_proc.call(res_data['LastEvaluatedKey'])
            items = block_given? ? res_data['Items'].map {|i| yield(i) } : res_data['Items']

            retval.concat(items)

            if parsed.limit
              parsed.limit -= items.length
              break if parsed.limit < 1
            end
          end
        end
      end

      parsed.limit = limit_orig;

      if res_data['LastEvaluatedKey']
        @last_action = action
        @last_parsed = parsed
        @last_evaluated_key = res_data['LastEvaluatedKey']
        retval = DynamoDB::Iteratorable.new(retval, res_data['LastEvaluatedKey'])
      else
        @last_action = nil
        @last_parsed = nil
        @last_evaluated_key = nil
      end

      return retval
    end

    def do_get(parsed)
      req_hash = {'TableName' => parsed.table}
      req_hash['AttributesToGet'] = parsed.attrs unless parsed.attrs.empty?
      req_hash['ConsistentRead'] = @consistent if @consistent

      # key
      req_hash['Key'] = {}

      parsed.conds.each do |key, val|
        req_hash['Key'][key] = convert_to_attribute_value(val)
      end # key

      convert_to_ruby_value(@client.query('GetItem', req_hash)['Item'])
    end

    def do_update(parsed)
      req_hash = {
        'TableName' => parsed.table,
      }

      # key
      req_hash['Key'] = {}

      parsed.conds.each do |key, val|
        req_hash['Key'][key] = convert_to_attribute_value(val)
      end # key

      # attribute updates
      req_hash['AttributeUpdates'] = {}

      parsed.attrs.each do |attr, val|
        h = req_hash['AttributeUpdates'][attr] = {}

        if val
          h['Action'] = parsed.action.to_s.upcase
          h['Value'] = convert_to_attribute_value(val)
        else
          h['Action'] = 'DELETE'
        end
      end # attribute updates

      @client.query('UpdateItem', req_hash)

      Rownum.new(1)
    end

    def do_update_all(parsed)
      items = scan_for_update(parsed)
      return Rownum.new(0) if items.empty?

      n = items.length

      items.each do |key_hash|
        req_hash = {
          'TableName' => parsed.table,
        }

        # key
        req_hash['Key'] = {}

        key_hash.each do |key, val|
          req_hash['Key'][key] = val
        end # key

        # attribute updates
        req_hash['AttributeUpdates'] = {}

        parsed.attrs.each do |attr, val|
          h = req_hash['AttributeUpdates'][attr] = {}

          if val
            h['Action'] = parsed.action.to_s.upcase
            h['Value'] = convert_to_attribute_value(val)
          else
            h['Action'] = 'DELETE'
          end
        end # attribute updates

        @client.query('UpdateItem', req_hash)
      end

      Rownum.new(n)
    end

    def do_delete(parsed)
      req_hash = {
        'TableName' => parsed.table,
      }

      # key
      req_hash['Key'] = {}

      parsed.conds.each do |key, val|
        req_hash['Key'][key] = convert_to_attribute_value(val)
      end # key

      @client.query('DeleteItem', req_hash)

      Rownum.new(1)
    end

    def do_delete_all(parsed)
      items = scan_for_update(parsed)
      return Rownum.new(0) if items.empty?

      n = items.length

      until (chunk = items.slice!(0, MAX_NUMBER_BATCH_PROCESS_ITEMS)).empty?
        operations = []

        req_hash = {
          'RequestItems' => {
            parsed.table => operations,
          },
        }

        chunk.each do |key_hash|
          operations << {
            'DeleteRequest' => {
              'Key' => key_hash,
            },
          }
        end

        batch_write_item(req_hash)
      end

      Rownum.new(n)
    end

    def scan_for_update(parsed)
      # DESCRIBE
      key_names = @client.query('DescribeTable', 'TableName' => parsed.table)['Table']['KeySchema']
      key_names = key_names.map {|h| h['AttributeName'] }

      items = []

      # SCAN
      scan = lambda do |last_evaluated_key|
        req_hash = {'TableName' => parsed.table}
        req_hash['AttributesToGet'] = key_names
        req_hash['Limit'] = parsed.limit if parsed.limit
        req_hash['Select'] = 'SPECIFIC_ATTRIBUTES'
        req_hash['ExclusiveStartKey'] = last_evaluated_key if last_evaluated_key

        # XXX: req_hash['ReturnConsumedCapacity'] = ...

        # scan filter
        if parsed.conds
          req_hash['ScanFilter'] = {}

          parsed.conds.each do |key, operator, values|
            h = req_hash['ScanFilter'][key] = {
              'ComparisonOperator' => operator.to_s
            }

            h['AttributeValueList'] = values.map do |val|
              convert_to_attribute_value(val)
            end
          end
        end # scan filter

        res_data = @client.query('Scan', req_hash)
        res_data_items = res_data['Items']
        parsed.limit -= res_data_items.length if parsed.limit
        items.concat(res_data_items)
        res_data['LastEvaluatedKey']
      end

      lek = nil

      loop do
        lek = scan.call(lek)

        if not lek or (parsed.limit and parsed.limit < 1)
          break
        end
      end

      return items
    end

    def convert_to_attribute_value(val)
      suffix = ''
      obj = val

      if val.kind_of?(Array)
        suffix = 'S'
        obj = val.first
        val = val.map {|i| i.to_s }
      else
        val = val.to_s
      end

      case obj
      when DynamoDB::Binary
        {"B#{suffix}" => val}
      when String
        {"S#{suffix}" => val}
      when Numeric
        {"N#{suffix}" => val}
      else
        raise 'must not happen'
      end
    end

    def convert_to_ruby_value(item)
      h = {}

      (item || {}).sort_by {|a, b| a }.map do |name, val|
        val = val.map do |val_type, ddb_val|
          case val_type
          when 'NS'
            ddb_val.map {|i| str_to_num(i) }
          when 'N'
            str_to_num(ddb_val)
          else
            ddb_val
          end
        end

        val = val.first if val.length == 1
        h[name] = val
      end

      return h
    end

    def do_insert(parsed)
      n = 0

      until (chunk = parsed.values.slice!(0, MAX_NUMBER_BATCH_PROCESS_ITEMS)).empty?
        operations = []

        req_hash = {
          'RequestItems' => {
            parsed.table => operations,
          },
        }

        chunk.each do |val_list|
          h = {}

          operations << {
            'PutRequest' => {
              'Item' => h,
            },
          }

          parsed.attrs.zip(val_list).each do |name, val|
            h[name] = convert_to_attribute_value(val)
          end
        end

        batch_write_item(req_hash)
        n += chunk.length
      end

      Rownum.new(n)
    end

    def do_insert_select(action, parsed)
      if parsed.select.count
        raise DynamoDB::Error, '"COUNT(*)" cannot be inserted.'
      end

      items = do_select0(action, parsed.select, :iteratable => true)
      items = items.data if items.kind_of?(Iteratorable)

      n = 0

      until (chunk = items.slice!(0, MAX_NUMBER_BATCH_PROCESS_ITEMS)).empty?
        operations = []

        req_hash = {
          'RequestItems' => {
            parsed.table => operations,
          },
        }

        chunk.each do |item|
          operations << {
            'PutRequest' => {'Item' => item}
          }
        end

        batch_write_item(req_hash)
        n += chunk.length
      end

      Rownum.new(n)
    end

    def str_to_num(str)
      str =~ /\./ ? str.to_f : str.to_i
    end

    def batch_write_item(req_hash)
      res_data = @client.query('BatchWriteItem', req_hash)

      until (res_data['UnprocessedItems'] || {}).empty?
        req_hash['RequestItems'] = res_data['UnprocessedItems']
        res_data = @client.query('BatchWriteItem', req_hash)
      end
    end

    def like_to_regexp(like)
      ss = StringScanner.new(like)
      tok = nil
      regexp = ''

      until ss.eos?
        if (tok = ss.scan /\\\\/)
          regexp << '\\'
        elsif (tok = ss.scan /\\%/)
          regexp << '%'
        elsif (tok = ss.scan /\\_/)
          regexp << '_'
        elsif (tok = ss.scan /%/)
          regexp << '.*'
        elsif (tok = ss.scan /_/)
          regexp << '.'
        elsif (tok = ss.scan /[^\\%_]+/)
          regexp << tok
        end
      end

      Regexp.compile("\\A#{regexp}\\Z")
    end

  end # Driver
end # DynamoDB
