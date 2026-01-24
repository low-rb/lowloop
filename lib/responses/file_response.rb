# frozen_string_literal: true

require_relative '../factories/response_factory'

module Low
  class FileResponse
    class << self
      def handle(event:)
        file = event.file

        if File.exist?(file.path)
          response = Factories::ResponseFactory.file(path: file.path, content_type: file.content_type)
          return Events::ResponseEvent.new(response:)
        end

        nil
      end
    end
  end
end
