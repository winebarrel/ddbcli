require 'tempfile'

def ddbcli(input = nil, args = [])
  if input
    Tempfile.open('ddbcli') do |f|
      f << input
      input = f.path
    end
  end

  out = `ddbcli #{args.join(' ')}`
  out.strip
end
