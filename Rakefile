# frozen_string_literal: true

require 'English'
require 'rake/testtask'
require 'rake/packagetask'

# Task to check Ruby syntax
desc 'Check Ruby files for syntax errors'
task :syntax do
  ruby_files = FileList['lib/**/*.rb', 'test/**/*.rb', '*.rb']
  ruby_files.each do |file|
    sh "ruby -c #{file}"
    puts "\n"
  end
end

# Task to run tests
desc 'Run tests'
task :test do
  system 'rspec'
  raise 'Tests failed' unless $CHILD_STATUS.success?
end

# Task to create a gem package
desc 'Create a gem package'
Rake::PackageTask.new('autosparkle', Gem::Specification.load('autosparkle.gemspec').version) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
  pkg.package_dir = 'pkg'
  pkg.package_files.include('lib/**/*')
  pkg.package_files.include('bin/**/*')
end

# Task to build the gem
desc 'Build the gem'
task :build do
  system 'gem build autosparkle.gemspec'
  raise 'Gem build failed' unless $CHILD_STATUS.success?
end

# Task to install the gem
desc 'Install the gem'
task install: :build do
  gem_file = Dir['*.gem'].first
  system "gem install #{gem_file}"
  raise 'Gem install failed' unless $CHILD_STATUS.success?
end

# Task to run the default tasks
task default: %i[syntax test]
