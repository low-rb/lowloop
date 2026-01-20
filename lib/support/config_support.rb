# frozen_string_literal: true

module ConfigSupport
  class << self
    def parse_boolean(value)
      return true if value == '1'
      return false if value == '0'

      nil
    end
  end
end
