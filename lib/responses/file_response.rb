# frozen_string_literal: true

require_relative '../responses/response_factory'

module Low
  class FileResponse
    class << self
      def request(event:)
        file = event.file

        if File.exist?(file.path)
          response = ResponseFactory.file(path: file.path, content_type: file.content_type)
          return Events::ResponseEvent.new(response:).tap(&:branch)
        end

        nil
      end
    end
  end
end
