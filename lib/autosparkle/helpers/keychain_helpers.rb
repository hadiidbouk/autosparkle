require 'securerandom'
require 'open3'
require 'base64'
require_relative 'build_directory_helpers'
require_relative 'constants'
require_relative 'commands_helpers'
require_relative 'puts_helpers'

#
# Execute the given block with a temporary keychain,
# The block will receive the application certificate name and team id as arguments.
# The temporary keychain will be deleted after the block has been executed.
#
def with_temporary_keychain
  keychain_name = "temporary.autosparkle.keychain-#{SecureRandom.uuid}"
  keychain_path = "~/Library/Keychains/#{keychain_name}-db"
  password = SecureRandom.hex(16)

  original_keychain_list = `security list-keychains`.strip.split("\n").map(&:strip)
  default_keychain = execute_command('security default-keychain')
  default_keychain_path = default_keychain.gsub(/"(.*)"/, '\1').strip

  delete_temporary_keychain_if_needed(keychain_path)

  begin
    # Create a temporary keychain
    create_temporary_keychain(keychain_path, password, original_keychain_list)
    import_certificates_in_temporary_keychain(keychain_path)
    execute_command("security set-key-partition-list -S apple-tool:,apple:,codesign: \\
                  -s -k \"#{password}\" #{keychain_path}")

    # Fetch the certificate names and team ids from the temporary keychain
    application_cert_name, application_team_id = fetch_application_certificate_info(keychain_path)
    store_notarization_credentials(keychain_path, application_team_id)

    keychain_info = {
      keychain_path: keychain_path,
      application_cert_name: application_cert_name,
      application_team_id: application_team_id
    }
    yield(keychain_info) if block_given?
  ensure
    puts_if_verbose 'Ensuring cleanup of temporary keychain...'
    delete_temporary_keychain_if_needed(keychain_path)

    # Reset the keychain to the default
    execute_command("security list-keychains -s #{original_keychain_list.join(' ')}")
    execute_command("security default-keychain -s \"#{default_keychain_path}\"")
  end
end

private

def create_temporary_keychain(keychain_path, password, original_keychain_list)
  execute_command("security create-keychain -p \"#{password}\" #{keychain_path}")
  execute_command("security unlock-keychain -p \"#{password}\" #{keychain_path}")
  execute_command("security list-keychains -d user -s #{(original_keychain_list + [keychain_path]).join(' ')}")
  execute_command("security default-keychain -s #{keychain_path}")
end

def store_notarization_credentials(keychain_path, application_team_id)
  command = "xcrun notarytool store-credentials #{Constants::NOTARIZE_KEYCHAIN_PROFILE} \\
						--keychain #{keychain_path} \\
						--apple-id #{Env.variables.apple_id} \\
						--team-id #{application_team_id} \\
						--password #{Env.variables.app_specific_password}"
  execute_command(command)
end

def import_certificates_in_temporary_keychain(keychain_path)
  developer_id_application_p12 = Base64.decode64(Env.variables.developer_id_application_base64 || '')

  # Create temporary files for the .p12 certificates
  application_cert_file = BuildDirectory.new_file('application_cert.p12')

  # Write the decoded .p12 data to the temporary files
  application_cert_file.write(developer_id_application_p12)
  application_cert_file.close

  # Import the certificates into the temporary keychain
  import_file_to_keychain(keychain_path, application_cert_file.path,
                          Env.variables.developer_id_application_password)
end

def import_file_to_keychain(keychain_path, file_path, password)
  command = "security import #{file_path} -k #{keychain_path} -P #{password}"
  command += ' -T /usr/bin/codesign'
  command += ' -T /usr/bin/security'
  command += ' -T /usr/bin/productbuild'
  command += ' -T /usr/bin/productsign'
  execute_command(command)
end

def fetch_certificate_info(keychain_path, certificate_type)
  command = "security find-certificate -c \"#{certificate_type}\" #{keychain_path} | grep \"labl\" | sed -E 's/^.*\"labl\"<blob>=\"(.*)\".*/\\1/'"
  name = `#{command}`.strip
  team_id = name[/\(([^)]+)\)$/, 1]
  [name, team_id]
end

def fetch_application_certificate_info(keychain_path)
  fetch_certificate_info(keychain_path, 'Developer ID Application')
end

def delete_temporary_keychain_if_needed(keychain_path)
  execute_command("security delete-keychain #{keychain_path}") if File.exist?(File.expand_path(keychain_path.to_s))
end
