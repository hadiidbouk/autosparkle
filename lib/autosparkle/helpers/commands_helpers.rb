# frozen_string_literal: true

require 'colorize'
require 'english'
require_relative '../environment/environment'

#
# This method executes a command and returns the output
# It raises an error if the command fails
#
def execute_command(command, contains_sensitive_data: false)
  # if the command has --password, --secret then replace it with *****
  presented_command = command.gsub(/(--password|--secret) \S+/, '\1 *****')

  puts "\n#{presented_command}\n".cyan if Env.verbose_enabled && !contains_sensitive_data
  stdout, stderr, status = Open3.capture3(command)

  # if status is not success
  unless status.success?
    puts "\nCommand failed: #{command}\n".red
    puts "\nError: #{stderr}\n".red
    raise
  end

  puts "#{stdout}\n\n".magenta if Env.verbose_enabled && !contains_sensitive_data

  stdout
end
