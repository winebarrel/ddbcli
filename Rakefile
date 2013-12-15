require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new('spec')

task :default => :spec

task :pack_scripts do
  system(File.dirname(__FILE__) + '/etc/pack_to_one_script.rb')
end
