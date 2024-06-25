# frozen_string_literal: true

require 'colorize'
require_relative 'helpers/build_directory_helpers'
require_relative 'helpers/commands_helpers'
require_relative 'helpers/puts_helpers'
require_relative 'helpers/constants'
require_relative 'helpers/appcast_helpers'
require_relative 'environment/environment'

# Distribution module to sign the update and upload it to the server
module Distribution
  def self.upload_update(pkg_path)
    puts_title 'Uploading the update to the server'
    ed_signature_fragment = sign_update(pkg_path)

    appcast_xml = AppcastXML.generate_appcast_xml(ed_signature_fragment, Env.storage.deployed_appcast_xml)
    upload_update_to_server(pkg_path, appcast_xml)

    app_display_name = Env.variables.app_display_name
    version = Env.variables.marketing_version
    build_version = Env.variables.current_project_version
    puts "#{app_display_name} version #{version} (#{build_version}) has been uploaded successfully. ✅ 🚀".green
  end

  def self.sign_update(pkg_path)
    puts_if_verbose 'Signing the update...'
    sign_update_path = File.join(__dir__, 'sparkle', 'sign_update')
    sign_command = "echo \"#{Env.variables.sparkle_private_key}\" | "
    sign_command += "#{sign_update_path} \"#{pkg_path}\" --ed-key-file -"
    execute_command(sign_command, contains_sensitive_data: true)
  end

  def self.upload_update_to_server(pkg_path, appcast_xml)
    puts_if_verbose 'Uploading the update to the server...'
    appcast_file = BuildDirectory.new_file('appcast.xml')
    appcast_file.write(appcast_xml)
    appcast_file.close

    Env.storage.upload(pkg_path, appcast_file.path)
  end
end
