require 'rake'
require 'bundler/gem_tasks'

task default: :spec

task :clean do
  puts 'Cleaning up...'
  sh 'rm -rf ~/Library/Developer/autosparkle/build'
end

task :test do
  puts 'Running tests...'
  sh 'rspec'
end
