require 'optparse'
require 'securerandom'
require_relative 'packaging'
require_relative 'distribution'
require_relative 'helpers/build_directory_helpers'
require_relative 'helpers/commands_helpers'
require_relative 'helpers/keychain_helpers'
require_relative 'helpers/xcodeproj_helpers'
require_relative 'helpers/puts_helpers'
require_relative 'environment/environment'

def extract_options
  options = {}

  OptionParser.new do |opts|
    opts.banner = 'Usage: automate-sparkle.rb [options]'

    opts.on('--project-path PATH', 'Path to the Xcode project') do |path|
      options[:project_path] = path
    end

    opts.on('--workspace-path PATH', 'Path to the Xcode workspace') do |path|
      options[:workspace_path] = path
    end

    env_description = 'Environment to load (aka. local, production)'
    env_description += ' it will look inside the Xcode project/workspace path'
    env_description += ' for a file named `.autosparkle.env.<environment>`'

    opts.on('--env ENVIRONMENT', env_description) do |env|
      options[:env] = env
    end

    opts.on('--env-file PATH', 'Path to the environment file') do |path|
      options[:env_file] = path
    end

    opts.on('-v', 'Enable verbose mode') do |verbose|
      Env.verbose_enabled = verbose
    end
  end.parse!

  # Check if both project path and environment are specified
  unless (options[:workspace_path] || options[:project_path]) && (options[:env] || options[:env_file])
    raise 'Xcode Project/Workspace path and Environment/Environment file are required.'
  end

  options
end

options = extract_options
Env.initialize(options)

Xcodeproj.check_sparkle_configuration_existence(options[:project_path], options[:workspace_path])

BuildDirectory.create_build_directory

puts "Automating the delivery of #{Env.variables.app_display_name} version #{Env.variables.marketing_version} (#{Env.variables.current_project_version})..."
dmg_path = nil
with_temporary_keychain do |keychain_info|
  exported_app_path = Packaging.archive_and_sign(
    keychain_info[:application_cert_name],
    keychain_info[:application_team_id],
    options
  )
  dmg_path = Packaging.create_and_sign_dmg(
    exported_app_path,
    keychain_info[:application_cert_name],
    keychain_info[:keychain_path]
  )
end

Distribution.upload_update(dmg_path)
