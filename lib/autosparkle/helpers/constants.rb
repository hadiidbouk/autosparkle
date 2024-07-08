# frozen_string_literal: true

# Constants module to store the constants used in the application
module Constants
  NOTARIZE_KEYCHAIN_PROFILE = 'autosparkle.keychain.notarize.profile'
  AUTOSPARKLE_BUILD_DIRECTORY_PATH = '~/Library/Developer/autosparkle/build'
  KEYCHAIN_NAME = 'temporary.autosparkle.keychain'
  KEYCHAIN_PATH = "~/Library/Keychains/#{KEYCHAIN_NAME}-db"
  KEYCHAIN_PASSWORD = 'autosparkle'
end
