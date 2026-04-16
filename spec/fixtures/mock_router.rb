# frozen_string_literal: true

require 'observers'
require_relative '../../lib/low_loop'

class MockRouter
  include Observers

  def handle(event:)
    # Return value is stubbed.
  end
end
