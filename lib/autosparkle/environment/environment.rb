# frozen_string_literal: true

require 'dotenv'
require 'nokogiri'
require_relative '../helpers/appcast_helpers'
require_relative '../helpers/puts_helpers'
require_relative '../storages/aws_s3_storage'
require_relative 'variables/default_environment_variables'

# Environment module to load the environment variables
# It contains the app state
module Env
  @variables = nil
  @storage = nil
  @verbose_enabled = false

  class << self
    attr_accessor :variables, :storage, :verbose_enabled

    def initialize(options)
      project_path = options[:project_path]
      workspace_path = options[:workspace_path]
      project_directory_path = File.dirname(workspace_path || project_path)

      load_environment(project_directory_path, options)

      @variables = DefaultEnvironmentVariables.new(project_directory_path)
      @storage = retrieve_storage

      retrieve_variables_from_xcode(project_path, workspace_path)
      set_up_app_versions(project_path, workspace_path)

      puts_if_verbose "Running the script with the #{options[:env]} environment...\n"
    end
  end

  def self.load_environment(project_directory_path, options)
    env_file_path = options[:env_file] || File.join(project_directory_path, ".env.autosparkle.#{options[:env]}")
    raise "#{env_file_path} does not exist." unless File.exist?(env_file_path)

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

  def self.set_up_app_versions(project_path, workspace_path)
    marketing_version, current_project_version = AppcastXML.retreive_versions(@storage.deployed_appcast_xml)

    ENV['MARKETING_VERSION'] = marketing_version
    ENV['CURRENT_PROJECT_VERSION'] = current_project_version

    puts_if_verbose 'Updating the project versions from the environment variables...'
    Xcodeproj.update_project_version(project_path, workspace_path)
  end
end
