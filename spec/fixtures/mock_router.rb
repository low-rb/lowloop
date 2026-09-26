# frozen_string_literal: true

require 'observers'
require_relative '../../lib/lowloop'

class MockRouter
  include Observers

  def request(event:)
    # Return value is stubbed.
  end
end
