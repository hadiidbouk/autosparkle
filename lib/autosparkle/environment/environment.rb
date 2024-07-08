# frozen_string_literal: true

require 'dotenv'
require 'nokogiri'
require_relative '../helpers/appcast_helpers'
require_relative '../helpers/puts_helpers'
require_relative '../storages/aws_s3_storage'
require_relative 'variables/default_environment_variables'

module Command
  EXPORT = 0
  PACKAGE = 1
  DISTRIBUTE = 2
  AUTOMATE = 3
end

# Environment module to load the environment variables
# It contains the app state
module Env
  @variables = nil
  @storage = nil
  @verbose_enabled = false

  class << self
    attr_accessor :variables, :storage, :verbose_enabled

    def initialize(options, command)
      project_path = options.project_path
      workspace_path = options.workspace_path

      project_directory_path = File.dirname(workspace_path || project_path) if workspace_path || project_path
      ENV['PROJECT_DIRECTORY_PATH'] = project_directory_path

      load_environment(project_directory_path, options.env)

      @variables = DefaultEnvironmentVariables.new

      case command
      when Command::EXPORT
        initialize_export(options)
      when Command::PACKAGE
        initialize_package(options)
      when Command::DISTRIBUTE
        initialize_distribute(options)
      when Command::AUTOMATE
        initialize_automate(options)
      end

      puts_if_verbose "Running the script with the #{options.env} environment...\n"
    end
  end

  def self.initialize_export(options)
    retrieve_variables_from_xcode(options.project_path, options.workspace_path)
  end

  def self.initialize_package(options)
    ENV['APP_DISPLAY_NAME'] = options.app_display_name
  end

  def self.initialize_distribute(options)
    ENV['APP_DISPLAY_NAME'] = options.app_display_name
    ENV['MINIMUM_MACOS_VERSION'] = options.minimum_macos_version

    @storage = retrieve_storage
    retreive_versions_variables_form_appcast(options)
  end

  def self.initialize_automate(options)
    retrieve_variables_from_xcode(options.project_path, options.workspace_path)

    @storage = retrieve_storage
    retreive_versions_variables_form_appcast(options)
  end

  def self.load_environment(project_directory_path, env)
    env_is_file = File.file?(env)
    if !project_directory_path && !env_is_file
      raise 'Cannot find the project directory path to load the environment variables'
    end

    env_file_path = if env_is_file
                      env
                    else
                      File.join(project_directory_path, ".env.autosparkle.#{env}")
                    end

    ENV['ENV_FILE_PATH'] = env_file_path
    puts_if_verbose "Loading the environment variables from #{env_file_path}..."
    Dotenv.load(env_file_path)
  end

  def self.retrieve_storage
    storage_type = ENV.fetch('STORAGE_TYPE', nil)
    raise 'Storage type is not defined in the environment' if storage_type.nil? || storage_type.empty?

    case storage_type
    when 'aws-s3'
      AwsS3Storage.new
    else
      raise "Storage type #{storage_type} is not supported"
    end
  end

  def self.retrieve_variables_from_xcode(project_path, workspace_path)
    puts_if_verbose 'Fetching the minimum macOS version from the Xcode project...'
    ENV['MINIMUM_MACOS_VERSION'] = Xcodeproj.get_minimum_deployment_macos_version(project_path, workspace_path)

    puts_if_verbose 'Fetching the app display name from the Xcode project...'
    ENV['APP_DISPLAY_NAME'] = Xcodeproj.get_app_display_name(project_path, workspace_path)
  end

  def self.retreive_versions_variables_form_appcast(options)
    marketing_version, current_project_version = AppcastXML.retreive_versions(@storage.deployed_appcast_xml)

    ENV['MARKETING_VERSION'] = options.marketing_version || marketing_version
    ENV['CURRENT_PROJECT_VERSION'] = options.current_project_version || current_project_version
  end
end
