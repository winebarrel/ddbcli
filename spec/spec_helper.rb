require 'json'
require 'pp'
require 'tempfile'

%w(AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION).each do |name|
  ENV[name] = ENV["DDBCLI_TEST_#{name}"] || '(empty)'
end

def ddbcli(input = nil, args = [])
  if input
    Tempfile.open('ddbcli') do |f|
      f << input
      input = f.path
    end
  end

  cmd = File.expand_path(File.dirname(__FILE__) + '/../bin/ddbcli')
  out = nil

  args = ['--url', 'localhost:8000'] + args

  if input
    out = `cat #{input} | #{cmd} #{args.join(' ')} 2>&1`
  else
    out = `#{cmd} #{args.join(' ')} 2>&1`
  end

  raise out unless $?.success?

  out.strip
end

def clean_tables
  show_tables = lambda do
    out = ddbcli('show tables')
    JSON.parse(out)
  end

  show_tables.call.each do |name|
    begin
      ddbcli("drop table #{name}")
    rescue => e
      if e.message =~ /Attempt to change a resource which is still in use: Table is being created/
        sleep 1
        retry
      else
        raise e
      end
    end
  end

  until show_tables.call.empty?
    sleep 1
  end
end

RSpec.configure do |config|
  config.before(:each) do
    clean_tables
  end
end
