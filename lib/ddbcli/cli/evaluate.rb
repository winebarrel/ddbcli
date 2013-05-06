def evaluate_query(driver, src, opts = {})
  ss = StringScanner.new(src.dup)
  buf = ''

  until ss.eos?
    if (tok = ss.scan %r{[^`'";\\/#]+}) #'
      buf << tok
    elsif (tok = ss.scan /`(?:[^`]|``)*`/)
      buf << tok
    elsif (tok = ss.scan /'(?:[^']|'')*'/) #'
      buf << tok
    elsif (tok = ss.scan /"(?:[^"]|"")*"/) #"
      buf << tok
    elsif (tok = ss.scan %r{/\*/?(?:\n|[^/]|[^*]/)*\*/})
      # nothing to do
    elsif (tok = ss.scan /--[^\r\n]*(?:\r\n|\r|\n|\Z)/)
      # nothing to do
    elsif (tok = ss.scan /#[^\r\n]*(?:\r\n|\r|\n|\Z)/)
      # nothing to do
    elsif (tok = ss.scan /(?:\\;)/)
      buf << ';' # escape of ';'
    elsif (tok = ss.scan /(?:;|\\G)/)
      src.replace(ss.rest)
      query = buf
      buf = ''

      if query.strip.empty?
        print_error('No query specified')
        next
      end

      start_time = Time.new
      out = driver.execute(query)
      elapsed = Time.now - start_time

      if out.kind_of?(DynamoDB::Driver::Rownum)
        print_rownum(out, :time => elapsed)
      elsif out.kind_of?(String)
        puts out
      elsif out
        opts = opts.merge(:inline => (tok != '\G'), :time => elapsed)
        print_json(out, opts)
      end
    elsif (tok = ss.scan /./)
      buf << tok # 落ち穂拾い
    end
  end

  src.replace(buf.strip)
  buf
end
