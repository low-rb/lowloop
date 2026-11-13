# frozen_string_literal: true

require_relative '../responses/response_factory'

module Low
  class FileResponse
    class << self
      def request(event:)
        file = event.file
        return nil unless File.exist?(file.path)

        path = file.path
        cache_control = file.cache_control
        return respond(ResponseFactory.not_modified(path:, cache_control:)) if unchanged?(path, event.request)

        respond(ResponseFactory.file(path:, content_type: file.content_type, cache_control:))
      end

      private

      def respond(response)
        Events::ResponseEvent.new(response:).tap(&:branch)
      end

      def unchanged?(path, request)
        since = request&.headers&.[]('if-modified-since')
        return false unless since

        File.mtime(path).to_i <= Time.httpdate(Array(since).first.to_s).to_i
      rescue ArgumentError
        false
      end
    end
  end
end
