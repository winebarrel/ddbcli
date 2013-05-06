def print_error(errmsg, opts = {})
  errmsg = errmsg.join("\n") if errmsg.kind_of?(Array)
  errmsg = errmsg.strip.split("\n").map {|i| "// #{i.strip}" }.join("\n")
  errmsg += "\n\n" unless opts[:strip]
  $stderr.puts errmsg
end

def print_rownum(data, opts = {})
  rownum = data.to_i
  msg = "// #{rownum} #{rownum > 1 ? 'rows' : 'row'} changed"
  msg << " (%.2f sec)" % opts[:time] if opts[:time]
  msg << "\n\n"
  puts msg
end

def print_version
  puts "#{File.basename($0)} #{Version}"
end

def print_json(data, opts = {})
  str = nil
  last_evaluated_key = nil

  if data.kind_of?(DynamoDB::Iteratorable)
    last_evaluated_key = data.last_evaluated_key
    data = data.data
  end

  if data.kind_of?(Array) and opts[:inline]
    str = "[\n"

    data.each_with_index do |item, i|
      str << "  #{item.to_json}"
      str << ',' if i < (data.length - 1)
      str << "\n"
    end

    str << "]"
  else
    if data.kind_of?(Array) or data.kind_of?(Hash)
      str = JSON.pretty_generate(data)
    else
      str = data.to_json
    end
  end

  str.sub!(/(?:\r\n|\r|\n)*\Z/, "\n")

  if opts[:show_rows] and data.kind_of?(Array)
    str << "// #{data.length} #{data.length > 1 ? 'rows' : 'row'} in set"
    str << " (%.2f sec)" % opts[:time] if opts[:time]
    str << "\n"
  end

  if last_evaluated_key
    str << "// has more\n"
  end

  str << "\n"
  puts str
end

def evaluate_command(driver, cmd_arg)
  cmd, arg = cmd_arg.split(/\s+/, 2).map {|i| i.strip }
  arg = nil if (arg || '').strip.empty?

  r = /\A#{Regexp.compile(cmd)}/i

  commands = {
    'help' => lambda {
      print_help
    },

    ['exit', 'quit'] => lambda {
      exit 0
    },

    'timeout' => lambda {
      case arg
      when nil
        puts driver.timeout
      when /\d+/
        driver.timeout = arg.to_i
      else
        print_error('Invalid argument')
      end
    },

    'consistent' => lambda {
      if arg
        r_arg = /\A#{Regexp.compile(arg)}/i

        if r_arg =~ 'true'
          driver.consistent = true
        elsif r_arg =~ 'false'
          driver.consistent = false
        else
          print_error('Invalid argument')
        end
      else
        puts driver.consistent
      end
    },

    'retry' => lambda {
      case arg
      when nil
        puts driver.retry_num
      when /\d+/
        driver.retry_num = arg.to_i
      else
        print_error('Invalid argument')
      end
    },

    'retry_interval' => lambda {
      case arg
      when nil
        puts driver.retry_intvl
      when /\d+/
        driver.retry_intvl = arg.to_i
      else
        print_error('Invalid argument')
      end
    },

    'debug' => lambda {
      if arg
        r_arg = /\A#{Regexp.compile(arg)}/i

        if r_arg =~ 'true'
          driver.debug = true
        elsif r_arg =~ 'false'
          driver.debug = false
        else
          print_error('Invalid argument')
        end
      else
        puts driver.debug
      end
    },

    'version' => lambda {
      print_version
    }
  }

  cmd_name, cmd_proc = commands.find do |name, proc|
    if name.kind_of?(Array)
      name.any? {|i| r =~ i }
    else
      r =~ name
    end
  end

  if cmd_proc
    cmd_proc.call
  else
    print_error('Unknown command')
  end
end
