# frozen_string_literal: true

require 'English'
require 'rake/testtask'
require 'rake/packagetask'

############# Common #############
desc 'Build the gem'
task :build do
  system 'gem build autosparkle.gemspec'
  raise 'Gem build failed' unless $CHILD_STATUS.success?
end

def retrieve_gem_version
  gemspec_content = File.read('autosparkle.gemspec')
  gemspec_content.match(/spec\.version\s*=\s*['"]([^'"]+)['"]/)[1]
end

############# CI #############
desc 'Check Ruby files for syntax errors'
task :syntax do
  ruby_files = FileList['lib/**/*.rb', 'test/**/*.rb', '*.rb']
  ruby_files.each do |file|
    sh "ruby -c #{file}"
    puts "\n"
  end
end

desc 'Run tests'
task :test do
  system 'bundle exec rspec'
  raise 'Tests failed' unless $CHILD_STATUS.success?
end

desc 'Install the gem'
task install: :build do
  gem_file = Dir['*.gem'].first
  system "gem install #{gem_file}"
  raise 'Gem install failed' unless $CHILD_STATUS.success?
end

############# CD #############
desc 'Bump the version'
task :bump_version do
  method = ENV.fetch('METHOD', nil)
  raise 'You must specify the method (major, minor, patch)' unless method

  # Read the gemspec file
  gemspec_file = 'autosparkle.gemspec'
  gemspec_content = File.read(gemspec_file)

  new_version = nil

  # Update the version line
  new_gemspec_content = gemspec_content.gsub(/(spec\.version\s*=\s*['"])([^'"]+)(['"])/) do
    prefix = Regexp.last_match(1)
    current_version = Regexp.last_match(2)
    suffix = Regexp.last_match(3)

    major, minor, patch = current_version.split('.').map(&:to_i)

    case method
    when 'major'
      major += 1
      minor = 0
      patch = 0
    when 'minor'
      minor += 1
      patch = 0
    when 'patch'
      patch += 1
    end

    new_version = [major, minor, patch].join('.')
    "#{prefix}#{new_version}#{suffix}"
  end

  # Write the updated content back to the file
  File.write(gemspec_file, new_gemspec_content)

  puts "Bumped version to #{new_version}"
end

desc 'Push the new version to the repository'
task :push_version do
  # Set the git configuration
  system 'git config --global user.email "hadiidbouk@gmail.com"'
  system 'git config --global user.name "Hadi Dbouk"'

  # Push the changes to the develop branch
  system 'git pull origin develop'
  system 'git checkout develop'
  system 'git add autosparkle.gemspec'
  system "git commit -m 'Bump version to #{retrieve_gem_version}'"
  system 'git push origin develop'

  # Retreive the last commit hash
  commit_hash = `git rev-parse HEAD`.strip

  # Push the changes to the main branch
  system 'git checkout main'
  system 'git pull origin main'
  system "git cherry-pick #{commit_hash}"
  system 'git push origin main'
rescue StandardError
  raise e
end

desc 'Create a gem package'
Rake::PackageTask.new('autosparkle', Gem::Specification.load('autosparkle.gemspec').version) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
  pkg.package_dir = 'pkg'
  pkg.package_files.include('lib/**/*')
  pkg.package_files.include('bin/**/*')
end

desc 'Publish a new gem version'
task :publish_gem do
  ruby_gem_api_key = ENV.fetch('GEM_HOST_API_KEY', nil)
  raise 'You must provide the GEM_HOST_API_KEY secret' unless ruby_gem_api_key

  system "gem push autosparkle-*.gem --key #{ruby_gem_api_key}"
  raise 'gem push failed' unless $CHILD_STATUS.success?
end

desc 'Release the package on GitHub and create a tag'
task :release_package do
  # Get the current version from the gemspec file
  current_version = Gem::Specification.load('autosparkle.gemspec').version.to_s

  begin
    # Create a git tag
    system "git tag v#{current_version}"
    system 'git push origin --tags'

    # Create a GitHub release
    system "gh release create v#{current_version} -t 'Release #{current_version}' --notes-from-tag --verify-tag"
  rescue StandardError
    raise e
  end
end
