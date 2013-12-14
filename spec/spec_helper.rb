require 'json'
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

  args = ['--url', 'localhost:8000'] + args
  out = nil

  if input
    out = `cat #{input} | ddbcli #{args.join(' ')} 2>&1`
  else
    out = `ddbcli #{args.join(' ')} 2>&1`
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
    ddbcli("drop table #{name}")
  end

  until show_tables.call.empty?
    sleep 1
  end
end

RSpec.configure do |config|
  config.before(:all) do
    clean_tables
  end

  config.before(:each) do
    # nothing to do
  end

  config.after(:all) do
    clean_tables
  end
end
