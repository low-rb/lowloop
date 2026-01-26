# frozen_string_literal: true

require 'ostruct'
require 'yaml'

module Low
  class ConfigLoader
    class << self
      def load(filepath, env = {})
        config_file = YAML.safe_load_file(filepath, symbolize_names: true)

        # Environment variables override config file.
        config_data = config_file.merge(env) do |_key, old_value, new_value|
          new_value.nil? ? old_value : new_value
        end

        OpenStruct.new(config_data)
      end

      def parse_boolean(value)
        return true if value == '1'
        return false if value == '0'

        nil
      end
    end
  end
end
