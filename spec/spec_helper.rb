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

  out = nil

  if input
    out = `ddbcli #{args.join(' ')}`
  else
    out = `cat #{input} | ddbcli #{args.join(' ')}`
  end

  out.strip
end

RSpec.configure do |config|
  config.before(:each) do
    # nothing to do
  end

  config.after(:all) do
    # nothing to do
  end
end
