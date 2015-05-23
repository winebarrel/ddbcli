# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ddbcli/version'

Gem::Specification.new do |spec|
  spec.name          = 'ddbcli'
  spec.version       = DynamoDB::VERSION
  spec.authors       = 'Genki Sugawara'
  spec.email         = 'sgwr_dts@yahoo.co.jp'
  spec.description   = 'ddbcli is an interactive command-line client of Amazon DynamoDB.'
  spec.summary       = spec.description
  spec.homepage      = 'https://github.com/winebarrel/ddbcli'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 2.14.1'
  spec.add_development_dependency 'racc'
end
