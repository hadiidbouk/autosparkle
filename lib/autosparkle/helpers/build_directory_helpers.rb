# frozen_string_literal: true

require 'fileutils'
require_relative 'constants'
require_relative 'puts_helpers'

# This module is used to create a new path inside the build directory
module BuildDirectory
  @build_directory_path = File.expand_path(Constants::AUTOSPARKLE_BUILD_DIRECTORY_PATH)

  def self.build_directory_path
    @build_directory_path
  end

  def self.create_build_directory
    if File.directory?(build_directory_path)
      puts_if_verbose 'Cleaning up the build directory...'
      FileUtils.rm_rf(build_directory_path)
    end

    puts_if_verbose "Creating the build directory at #{build_directory_path} ..."
    FileUtils.mkdir_p(build_directory_path)
  end

  def self.new_path(name)
    "#{build_directory_path}/#{name}"
  end

  def self.new_file(name)
    File.open(new_path(name), 'w')
  end

  def self.new_directory(name)
    path = new_path(name)
    FileUtils.mkdir_p(path)
    path
  end
end
