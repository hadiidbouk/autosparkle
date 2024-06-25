# frozen_string_literal: true

require_relative 'base_environment_variables'

# A class to load the AWS S3 environment variables
class AwsS3EnvironmentVariables < BaseEnvironmentVariables
  def initialize
    super({
      access_key: 'AWS_S3_ACCESS_KEY',
      secret_access_key: 'AWS_S3_SECRET_ACCESS_KEY',
      region: 'AWS_S3_REGION',
      bucket_name: 'AWS_S3_BUCKET_NAME'
    })
  end
end
