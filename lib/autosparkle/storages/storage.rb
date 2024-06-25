# frozen_string_literal: true

# This module is used as an interface for the storage classes
# It contains the methods that the storage classes should implement
# A storage can be for example Google Drive, Azure Blob Storage, AWS S3, etc.
# The update_file_destination_path method will return the path where the file should be uploaded
# The upload method is used to upload the package and the appcast file to the storage
module Storage
  def update_file_destination_path
    "#{Env.variables.marketing_version}/#{Env.variables.app_display_name}.dmg"
  end

  def upload(pkg_path, appcast_path)
    raise NotImplementedError, "This #{self.class} cannot respond to:"
  end

  def deployed_appcast_xml
    raise NotImplementedError, "This #{self.class} cannot respond to:"
  end
end
