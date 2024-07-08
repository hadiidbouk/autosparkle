# frozen_string_literal: true

require_relative '../../helpers/puts_helpers'
require_relative '../../helpers/xcodeproj_helpers'
require_relative 'base_environment_variables'

# A class to load the default environment variables
class DefaultEnvironmentVariables < BaseEnvironmentVariables
  def initialize
    super({
      env_file_path: 'ENV_FILE_PATH',
      project_directory_path: 'PROJECT_DIRECTORY_PATH',
      scheme: 'SCHEME',
      configuration: 'CONFIGURATION',
      marketing_version: 'MARKETING_VERSION',
      current_project_version: 'CURRENT_PROJECT_VERSION',
      minimum_macos_version: 'MINIMUM_MACOS_VERSION',
      app_display_name: 'APP_DISPLAY_NAME',
      apple_id: 'APPLE_ID',
      app_specific_password: 'APP_SPECIFIC_PASSWORD',
      developer_id_application_password: 'DEVELOPER_ID_APPLICATION_PASSWORD',
      developer_id_application_base64: 'DEVELOPER_ID_APPLICATION_BASE64',
      sparkle_private_key: 'SPARKLE_PRIVATE_KEY',
      sparkle_update_title: 'SPARKLE_UPDATE_TITLE',
      sparkle_release_notes: 'SPARKLE_RELEASE_NOTES',
      sparkle_bump_version_method: 'SPARKLE_BUMP_VERSION_METHOD',
      website_url: 'WEBSITE_URL',
      dmg_background_image: 'DMG_BACKGROUND_IMAGE',
      dmg_icon_size: 'DMG_ICON_SIZE',
      dmg_window_width: 'DMG_WINDOW_WIDTH',
      dmg_window_height: 'DMG_WINDOW_HEIGHT'
    })
  end
end
