# frozen_string_literal: true

# This module is used to bump the version of the app
# It receives the current version and the method to bump the version
# It returns the new version
module Version
  def self.bump(current_version, method)
    major, minor, patch = current_version.segments

    case method
    when 'major'
      major += 1
      # Reset minor and patch versions
      minor = 0
      patch = 0
    when 'minor'
      minor += 1
      # Reset patch version
      patch = 0
    when 'patch'
      patch += 1
    else
      raise ArgumentError, "Unknown bump method: #{method}"
    end

    "#{major}.#{minor}.#{patch}"
  end
end
