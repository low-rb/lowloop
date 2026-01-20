# frozen_string_literal: true

require 'low_event'

module Low
  module Events
    class FileEvent < LowEvent
      attr_reader :file, :request

      # TODO: For RouteEvent/FileEvent parse and provide query params as attributes on the event.
      def initialize(file:, request: nil)
        super()

        @file = file
        @request = request
      end
    end
  end
end
