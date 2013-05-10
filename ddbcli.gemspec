Gem::Specification.new do |spec|
  spec.name              = 'ddbcli'
  spec.version           = '0.1.4'
  spec.summary           = 'ddbcli is an interactive command-line client of Amazon DynamoDB.'
  spec.require_paths     = %w(lib)
  spec.files             = %w(README) + Dir.glob('bin/**/*') + Dir.glob('lib/**/*')
  spec.author            = 'winebarrel'
  spec.email             = 'sgwr_dts@yahoo.co.jp'
  spec.homepage          = 'https://bitbucket.org/winebarrel/ddbcli'
  spec.bindir            = 'bin'
  spec.executables << 'ddbcli'
  spec.add_dependency('json')
end
