# frozen_string_literal: true

require_relative 'helpers/build_directory_helpers'
require_relative 'helpers/constants'
require_relative 'helpers/commands_helpers'
require_relative 'helpers/dmg_helpers'
require_relative 'helpers/puts_helpers'
require_relative 'environment/environment'

# Packaging module to archive and sign the app
module Packaging
  def self.archive_and_sign(
    application_cert_name,
    application_cert_team_id,
    options
  )

    puts_title 'Archiving and signing the app'
    app_archive_path = BuildDirectory.new_path("#{Env.variables.app_display_name}.xcarchive")
    archive_command = 'xcodebuild clean analyze archive'
    archive_command += " -scheme #{Env.variables.scheme}"
    archive_command += " -archivePath '#{app_archive_path}'"
    archive_command += " CODE_SIGN_IDENTITY='#{application_cert_name}'"
    archive_command += " DEVELOPMENT_TEAM='#{application_cert_team_id}'"
    archive_command += " -configuration #{Env.variables.configuration}"
    archive_command += " OTHER_CODE_SIGN_FLAGS='--timestamp --options=runtime'"

    archive_command += if options[:workspace_path]
                         " -workspace #{options[:workspace_path]}"
                       else
                         " -project #{options[:project_path]}"
                       end

    execute_command(archive_command)

    puts_title 'Exporting the app'
    exported_app_path = export_app(app_archive_path, application_cert_name, application_cert_team_id)

    puts_title 'Signing the Sparkle framework'
    sign_sparkle_framework(
      exported_app_path,
      application_cert_name
    )

    exported_app_path
  end

  def self.export_app(app_archive_path, application_cert_name, team_id)
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

    "#{export_app_dir_path}/#{Env.variables.app_display_name}.app"
  end

  def self.create_and_sign_dmg(exported_app_path, application_cert_name, keychain_path)
    puts_title "Creating #{Env.variables.app_display_name}.dmg"
    puts_if_verbose 'Creating a DMG for the app...'
    dmg_path = DMG.create(exported_app_path)

    # Sign the DMG
    puts_if_verbose 'Signing the DMG...'
    execute_command("codesign --force --sign \"#{application_cert_name}\" --timestamp --options runtime \"#{dmg_path}\"")

    # Notarize the DMG
    puts_if_verbose 'Notarizing the DMG...'
    execute_command("xcrun notarytool submit \"#{dmg_path}\" --keychain-profile \"#{Constants::NOTARIZE_KEYCHAIN_PROFILE}\" --keychain \"#{keychain_path}\" --wait")

    # Staple the notarization ticket
    puts_if_verbose 'Stapling the notarization ticket...'
    execute_command("xcrun stapler staple \"#{dmg_path}\"")

    dmg_path
  end

  def self.sign_sparkle_framework(exported_app_path, application_cert_name)
    sparkle_auto_update_path = "#{exported_app_path}/Contents/Frameworks/Sparkle.framework/AutoUpdate"
    codesign('Signing Sparkle AutoUpdate...', application_cert_name, sparkle_auto_update_path)

    sparkle_updater_path = "#{exported_app_path}/Contents/Frameworks/Sparkle.framework/Updater.app"
    codesign('Signing Sparkle Updater...', application_cert_name, sparkle_updater_path)

    sparkle_installer_xpc_path = "#{exported_app_path}/Contents/Frameworks/Sparkle.framework/XPCServices/Installer.xpc/Contents/MacOS/Installer"
    codesign('Signing Sparkle Installer XPC Service...', application_cert_name, sparkle_installer_xpc_path)

    sparkle_downloader_xpc_path = "#{exported_app_path}/Contents/Frameworks/Sparkle.framework/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
    codesign('Signing Sparkle Downloader XPC Service...', application_cert_name, sparkle_downloader_xpc_path)

    sparkle_framework_path = "#{exported_app_path}/Contents/Frameworks/Sparkle.framework"
    codesign('Signing Sparkle framework...', application_cert_name, sparkle_framework_path)
  end

  def self.codesign(title, application_cert_name, path)
    puts_if_verbose title
    execute_command("codesign -f -o runtime --timestamp -s \"#{application_cert_name}\" \"#{path}\"")
  end
end
