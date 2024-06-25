# frozen_string_literal: true

require_relative '../../helpers/puts_helpers'

# The base envrionment variables class
class BaseEnvironmentVariables
  def initialize(variables)
    @variables = variables
  end

  def method_missing(method_name, *arguments, &block)
    key = method_name.to_sym
    if @variables.key?(key)
      value = ENV.fetch(@variables[key], nil)
      raise "#{@variables[key]} is not defined in the environment variables" if value.nil? || value.empty?

      value
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @variables.key?(method_name.to_sym) || super
  end
end
