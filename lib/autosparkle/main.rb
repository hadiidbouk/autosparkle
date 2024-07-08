# frozen_string_literal: true

require 'commander/import'
require 'fileutils'
require_relative 'metadata'
require_relative 'packaging'
require_relative 'distribution'
require_relative 'helpers/build_directory_helpers'
require_relative 'helpers/commands_helpers'
require_relative 'helpers/keychain_helpers'
require_relative 'helpers/xcodeproj_helpers'
require_relative 'helpers/puts_helpers'
require_relative 'helpers/dmg_helpers'
require_relative 'environment/environment'

program :name, AutoSparkle::NAME
program :version, AutoSparkle::VERSION
program :description, AutoSparkle::DESCRIPTION
program :help_formatter, :compact

default_command :help
global_option('--env ENVIRONMENT', String, 'Environment to load (aka. local, production) or a path to the env file')
global_option('--verbose', 'Enable verbose mode') { Env.verbose_enabled = true }

command :export do |c|
  c.syntax = "#{AutoSparkle::NAME} export [options]"
  c.description = 'Archive and export the macOS app'
  c.option('--project-path PATH', String, 'Path to the Xcode project')
  c.option('--workspace-path PATH', String, 'Path to the Xcode workspace')
  c.option('--skip-sparkle-steps', 'Skip the sparkle config check and signing the framework')
  c.option('--output-dir PATH', String, 'Path to the output directory')
  c.action do |_args, options|
    options.default \
      output_dir: Dir.pwd

    raise 'env name/path is required.' unless options.env
    raise 'Xcode Project/Workspace file is required.' unless options.workspace_path || options.project_path
    raise 'Environment/Environment file is required.' unless options.env || options.env_file

    BuildDirectory.create_build_directory
    Env.initialize(options, Command::EXPORT)

    unless options.skip_sparkle_steps
      Xcodeproj.check_sparkle_configuration_existence(
        options.project_path,
        options.workspace_path
      )
    end

    with_temporary_keychain do |keychain_info|
      archive_and_sign_hash = {
        application_cert_name: keychain_info[:application_cert_name],
        application_team_id: keychain_info[:application_team_id],
        project_path: options.project_path,
        workspace_path: options.workspace_path,
        output_dir: options.output_dir,
        skip_sparkle_steps: options.skip_sparkle_steps
      }

      exported_app_path = Packaging.archive_and_sign(archive_and_sign_hash)

      puts "Exported the app to #{exported_app_path}"
    end
  end
end

command :package do |c|
  c.syntax = "#{AutoSparkle::NAME} package [options]"
  c.description = 'Package the macOS app into a DMG file'
  c.option('--app-path PATH', String, 'Path to the exported app')
  c.option('--output-dir PATH', String, 'Path to the output directory')
  c.action do |_args, options|
    options.default \
      output_dir: Dir.pwd

    raise 'env name/path is required.' unless options.env
    raise 'App path is required.' unless options.app_path

    # Add the app-path file name without the extension to options
    app_path = File.expand_path(options.app_path)
    options.app_display_name = File.basename(app_path, '.*')

    BuildDirectory.create_build_directory
    Env.initialize(options, Command::PACKAGE)

    with_temporary_keychain do |keychain_info|
      dmg_path = Packaging.create_and_sign_dmg(
        app_path,
        keychain_info[:application_cert_name],
        options.output_dir
      )

      puts "Packaged the app into a DMG file at #{dmg_path}"
    end
  end
end

command :distribute do |c|
  c.syntax = "#{AutoSparkle::NAME} distribute [options]"
  c.description = 'Distribute your package to the specified storage and update the appcast.xml file'
  c.option('--dmg-path PATH', String, 'Path of the DMG file to be distributed')
  c.option('--app-display-name NAME', String, 'Name of the app inside the DMG without the .app extension')
  c.option('--marketing-version VERSION', String, 'Marketing version of the app')
  c.option('--current-project-version VERSION', String, 'Current project version of the app')
  c.option('--minimum-macos-version VERSION', String, 'Minimum macOS version required to run the app, defaults to 14.0')
  c.action do |_args, options|
    raise 'env name/path is required.' unless options.env
    raise 'dmg path is required, please pass it using --dmg-path' unless options.dmg_path
    raise 'No dmg file found at the specified path' unless File.exist?(options.dmg_path)
    raise 'App display name is required.' unless options.app_display_name

    options.default \
      minimum_macos_version: '14.0'

    BuildDirectory.create_build_directory
    Env.initialize(options, Command::DISTRIBUTE)

    Distribution.upload_update(options.dmg_path)
  end
end

command :automate do |c|
  c.syntax = "#{AutoSparkle::NAME} automate [options]"
  c.description = 'Automate the export, packaging, and distribution of the macOS app'
  c.option('--project-path PATH', String, 'Path to the Xcode project')
  c.option('--workspace-path PATH', String, 'Path to the Xcode workspace')
  c.action do |_args, options|
    raise 'env name/path is required.' unless options.env
    raise 'Xcode Project/Workspace path is required.' unless options.workspace_path || options.project_path

    BuildDirectory.create_build_directory
    Env.initialize(options, Command::AUTOMATE)

    app_version = "#{Env.variables.marketing_version} (#{Env.variables.current_project_version})"
    puts "Automating the delivery of #{Env.variables.app_display_name} version #{app_version} ..."

    Xcodeproj.update_project_version(options.project_path, options.workspace_path)

    dmg_path = nil
    with_temporary_keychain do |keychain_info|
      # 1. Export the app
      archive_and_sign_hash = {
        application_cert_name: keychain_info[:application_cert_name],
        application_team_id: keychain_info[:application_team_id],
        project_path: options.project_path,
        workspace_path: options.workspace_path
      }

      exported_app_path = Packaging.archive_and_sign(archive_and_sign_hash)

      # 2. Package the app
      dmg_path = Packaging.create_and_sign_dmg(
        exported_app_path,
        keychain_info[:application_cert_name],
        nil
      )
    end

    # 3. Distribute the app
    Distribution.upload_update(dmg_path)
  end
end
