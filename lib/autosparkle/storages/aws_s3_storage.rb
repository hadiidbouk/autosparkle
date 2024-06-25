# frozen_string_literal: true

require 'aws-sdk-s3'
require_relative 'storage'
require_relative '../environment/environment'
require_relative '../environment/variables/aws_s3_environment_variables'
require_relative '../helpers/puts_helpers'

# AwsS3Storage class to upload the updated version of the app
class AwsS3Storage
  include Storage
  def initialize
    @variables = AwsS3EnvironmentVariables.new

    credentials = Aws::Credentials.new(@variables.access_key, @variables.secret_access_key)
    Aws.config.update({
                        region: @variables.region,
                        credentials: credentials
                      })
    s3 = Aws::S3::Resource.new
    @bucket = s3.bucket(@variables.bucket_name)
    super
  end

  def upload(pkg_path, appcast_path)
    appcast_object = @bucket.object('appcast.xml')
    appcast_object.upload_file(appcast_path)

    puts_if_verbose "Uploaded the appcast file to the bucket #{@variables.bucket_name}"

    version_object = @bucket.object(update_file_destination_path)
    version_object.upload_file(pkg_path)

    puts_if_verbose "Uploaded version #{Env.variables.marketing_version} to the bucket #{@variables.bucket_name}"
  rescue StandardError => e
    raise "Failed to upload file: #{e.message}"
  end

  def deployed_appcast_xml
    appcast_object = @bucket.object('appcast.xml')
    appcast_object.get.body.read
  rescue StandardError
    nil
  end
end
