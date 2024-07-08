# frozen_string_literal: true

require 'Plist'
require_relative 'helpers/build_directory_helpers'
require_relative 'helpers/constants'
require_relative 'helpers/commands_helpers'
require_relative 'helpers/dmg_helpers'
require_relative 'helpers/puts_helpers'
require_relative 'environment/environment'

# Packaging module to archive and sign the app
module Packaging
  def self.archive_and_sign(hash)
    puts_title 'Archiving and signing the app'
    app_archive_path = BuildDirectory.new_path("#{Env.variables.app_display_name}.xcarchive")
    archive_command = 'xcodebuild clean analyze archive'
    archive_command += " -scheme #{Env.variables.scheme}"
    archive_command += " -archivePath '#{app_archive_path}'"
    archive_command += " CODE_SIGN_IDENTITY='#{hash[:application_cert_name]}'"
    archive_command += " DEVELOPMENT_TEAM='#{hash[:application_team_id]}'"
    archive_command += " -configuration #{Env.variables.configuration}"
    archive_command += " OTHER_CODE_SIGN_FLAGS='--timestamp --options=runtime'"

    archive_command += if hash[:workspace_path]
                         " -workspace #{hash[:workspace_path]}"
                       else
                         " -project #{hash[:project_path]}"
                       end

    execute_command(archive_command)

    puts_title 'Exporting the app'
    exported_app_path = export_app(
      app_archive_path,
      hash[:application_cert_name],
      hash[:application_team_id],
      hash[:output_dir]
    )

    unless hash[:skip_sparkle_steps]
      puts_title 'Signing the Sparkle framework'
      sign_sparkle_framework(
        exported_app_path,
        hash[:application_cert_name]
      )
    end

    exported_app_path
  end

  def self.export_app(
    app_archive_path,
    application_cert_name,
    team_id,
    output_dir
  )
    puts_if_verbose 'Exporting the app...'
    export_options = {
      signingStyle: 'automatic',
      method: 'developer-id',
      teamID: team_id,
      signingCertificate: application_cert_name,
      destination: 'export'
    }

    export_options_file = BuildDirectory.new_file('exportOptions.plist')
    plist_content = export_options.to_plist
    export_options_file.write(plist_content)
    export_options_file.close

    puts_if_verbose "exportOptions.plist:\n#{plist_content}"

    # Create temporary directory for the exported app
    export_app_dir_path = BuildDirectory.new_directory('exported_app')

    # Construct the export command
    export_command = "xcodebuild -exportArchive -archivePath \"#{app_archive_path}\""
    export_command += " -exportPath \"#{export_app_dir_path}\""
    export_command += " -exportOptionsPlist \"#{export_options_file.path}\""
    execute_command(export_command)

    exported_app_path = "#{export_app_dir_path}/#{Env.variables.app_display_name}.app"
    return exported_app_path unless output_dir

    FileUtils.cp_r(exported_app_path, output_dir)
    "#{output_dir}/#{Env.variables.app_display_name}.app"
  end

  def self.create_and_sign_dmg(
    exported_app_path,
    application_cert_name,
    output_dir
  )
    puts_title "Creating #{Env.variables.app_display_name}.dmg"
    puts_if_verbose 'Creating a DMG for the app...'
    dmg_path = DMG.create(exported_app_path)

    # Sign the DMG
    puts_if_verbose 'Signing the DMG...'
    signing_dmg_command = "codesign --force --sign \"#{application_cert_name}\""
    signing_dmg_command += " --timestamp --options runtime \"#{dmg_path}\""
    execute_command(signing_dmg_command)

    # Notarize the DMG
    puts_if_verbose 'Notarizing the DMG...'
    notarize_command = "xcrun notarytool submit \"#{dmg_path}\""
    notarize_command += " --keychain-profile \"#{Constants::NOTARIZE_KEYCHAIN_PROFILE}\""
    notarize_command += " --keychain \"#{Constants::KEYCHAIN_PATH}\""
    notarize_command += ' --wait'
    execute_command(notarize_command)

    # Staple the notarization ticket
    puts_if_verbose 'Stapling the notarization ticket...'
    execute_command("xcrun stapler staple \"#{dmg_path}\"")

    return dmg_path unless output_dir

    FileUtils.cp(dmg_path, output_dir)
    "#{output_dir}/#{Env.variables.app_display_name}.dmg"
  end

  def self.sign_sparkle_framework(exported_app_path, application_cert_name)
    sparkle_framework_path = "#{exported_app_path}/Contents/Frameworks/Sparkle.framework"

    sparkle_auto_update_path = "#{sparkle_framework_path}/AutoUpdate"
    codesign('Signing Sparkle AutoUpdate...', application_cert_name, sparkle_auto_update_path)

    sparkle_updater_path = "#{sparkle_framework_path}/Updater.app"
    codesign('Signing Sparkle Updater...', application_cert_name, sparkle_updater_path)

    sparkle_installer_xpc_path = "#{sparkle_framework_path}/XPCServices/Installer.xpc/Contents/MacOS/Installer"
    codesign('Signing Sparkle Installer XPC Service...', application_cert_name, sparkle_installer_xpc_path)

    sparkle_downloader_xpc_path = "#{sparkle_framework_path}/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
    codesign('Signing Sparkle Downloader XPC Service...', application_cert_name, sparkle_downloader_xpc_path)

    codesign('Signing Sparkle framework...', application_cert_name, sparkle_framework_path)
  end

  def self.codesign(title, application_cert_name, path)
    puts_if_verbose title
    execute_command("codesign -f -o runtime --timestamp -s \"#{application_cert_name}\" \"#{path}\"")
  end
end
