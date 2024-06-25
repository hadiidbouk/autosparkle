# frozen_string_literal: true

require 'colorize'
require_relative '../environment/environment'

def puts_if_verbose(message)
  puts message if Env.verbose_enabled
end

def puts_error(message)
  if message.is_a?(Array)
    puts message.map(&:red).join("\n")
  else
    puts message.red
  end
end

def puts_title(message)
  puts "\n🔷 #{message} ...\n".yellow
end
