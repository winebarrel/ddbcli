#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'stringio'

ROOT_DIR = Pathname.new(__FILE__).dirname.join('..').expand_path
LIB_DIR = ROOT_DIR.join('lib')

require LIB_DIR.join('ddbcli/version')

DEST_FILE = "pkg/ddbcli-#{DynamoDB::VERSION}"

def recursive_print(file, prefix, lib_path, fout, buf = [])
  return if buf.include?(file)

  buf << file
  path = lib_path.join(file)

  path.read.split("\n").each do |line|
    if line =~ %r|\A\s*require\s+['"](#{prefix}/.+)['"]\s*\Z|
      recursive_print($1 + '.rb', prefix, lib_path, fout, buf)
    else
      fout.puts line
    end
  end
end

def read_bin_file
  ROOT_DIR.join('bin/ddbcli').read.split("\n").select {|line|
    [
      /\A\s*#!/,
      /\A\s*\$LOAD_PATH/,
      /\A\s*require\s+['"]ddbcli\b/,
    ].all? {|r| line !~ r }
  }.join("\n")
end

ddbcli_buf = StringIO.new
recursive_print('ddbcli.rb', 'ddbcli', LIB_DIR, ddbcli_buf)

FileUtils.mkdir_p(ROOT_DIR.join(DEST_FILE).dirname)

ROOT_DIR.join(DEST_FILE).open('wb', 0755) do |f|
  f.puts '#!/usr/bin/env ruby'
  f.puts ddbcli_buf.string.gsub(%r|require\s+['"]json['"]|m, '')
  f.puts read_bin_file
end

puts "pack to #{DEST_FILE}."
