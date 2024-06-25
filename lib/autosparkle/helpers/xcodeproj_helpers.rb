require 'colorize'
require 'xcodeproj'
require 'plist'
require 'optparse'
require_relative '../environment/environment'
require_relative 'puts_helpers'

# Xcodeproj module to handle the fetch and manipulation of Xcode project
module Xcodeproj
  def self.get_app_display_name(project_path, workspace_path)
    _, target = get_app_target(project_path, workspace_path)
    build_settings = target.build_configurations.first.build_settings
    display_name = build_settings['PRODUCT_NAME']
    display_name = target.name if display_name == '$(TARGET_NAME)'
    display_name
  end

  def self.get_minimum_deployment_macos_version(project_path, workspace)
    _, target = get_app_target(project_path, workspace)
    config = target.build_configurations.first
    config.build_settings['MACOSX_DEPLOYMENT_TARGET']
  end

  def self.get_project_version(project_path, workspace_path)
    _, target = get_app_target(project_path, workspace_path)
    target.build_configurations.first.build_settings
    [build_settings['MARKETING_VERSION'], build_settings['CURRENT_PROJECT_VERSION']]
  end

  def self.update_project_version(project_path, workspace_path)
    project, target = get_app_target(project_path, workspace_path)
    target.build_configurations.each do |config|
      config.build_settings['MARKETING_VERSION'] = Env.variables.marketing_version
      config.build_settings['CURRENT_PROJECT_VERSION'] = Env.variables.current_project_version
    end
    project.save

    puts_if_verbose "Successfully updated the project version to #{Env.variables.marketing_version} and saved the project."
  end

  def self.get_app_target(project_path, workspace_path)
    project = Xcodeproj::Project.open(project_path) if project_path
    workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path) if workspace_path

    target = project.targets.find { |t| t.name == Env.variables.scheme } if project

    # If workspace is used, find the project containing the scheme
    if workspace && !target
      workspace.file_references.each do |file_reference|
        project_path = File.join(File.dirname(workspace_path), file_reference.path)
        project = Xcodeproj::Project.open(project_path)
        target = project.targets.find { |t| t.name == Env.variables.scheme }
        break if target
      end
    end

    raise "Target not found for scheme #{Env.variables.scheme_name}".red unless target

    [project, target]
  end

  def self.check_sparkle_configuration_existence(project_path, workspace_path)
    project, target = get_app_target(project_path, workspace_path)
    info_plist_file = project.files.find { |f| f.path.end_with?('Info.plist') }
    raise 'Info.plist not found in the project' unless info_plist_file

    info_plist_path = File.join(Env.variables.project_directory_path, "#{target.name}/#{info_plist_file.path}")
    info_plist = Xcodeproj::Plist.read_from_path(info_plist_path)

    raise 'Info.plist does not contain the needed Sparkle configuration: SUFeedURL'.red if info_plist['SUFeedURL'].nil?
    return unless info_plist['SUPublicEDKey'].nil?

    raise 'Info.plist does not contain the needed Sparkle configuration: SUPublicEDKey'.red
  end
end
