#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'stringio'

ROOT_DIR = Pathname.new(__FILE__).dirname.join('..').expand_path
LIB_DIR = ROOT_DIR.join('lib')

require LIB_DIR.join('ddbcli/version')

DEST_FILE = "pkg/ddbcli-#{DynamoDB::VERSION}"

JSON_VERSION = '1.8.1'
JSON_ARCHIVE = ROOT_DIR.join("v#{JSON_VERSION}.tar.gz")
JSON_ROOT_DIR = ROOT_DIR.join("json-#{JSON_VERSION}")
JSON_LIB_DIR = JSON_ROOT_DIR.join('lib')

def use_json
  system("wget -q https://github.com/flori/json/archive/#{JSON_ARCHIVE.basename}")
  system("tar xf #{JSON_ARCHIVE}")

  begin
    yield
  ensure
    FileUtils.rm_rf([JSON_ROOT_DIR, JSON_ARCHIVE])
  end
end

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

json_buf = StringIO.new

use_json do
  recursive_print('json/pure.rb', 'json', JSON_LIB_DIR, json_buf)
end

ddbcli_buf = StringIO.new
recursive_print('ddbcli.rb', 'ddbcli', LIB_DIR, ddbcli_buf)

FileUtils.mkdir_p(ROOT_DIR.join(DEST_FILE).dirname)

ROOT_DIR.join(DEST_FILE).open('wb', 0755) do |f|
  f.puts '#!/usr/bin/env ruby'
  f.puts json_buf.string
  f.puts ddbcli_buf.string.gsub(%r|require\s+['"]json['"]|m, '')
  f.puts read_bin_file
end

puts "pack to #{DEST_FILE}."
