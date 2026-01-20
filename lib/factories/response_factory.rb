# frozen_string_literal: true

require 'protocol/http'
require 'protocol/http/body/file'

module Low
  class ResponseFactory
    class << self
      def html(body:)
        headers = Protocol::HTTP::Headers.new(['content-type', 'text/html'])
        body = Protocol::HTTP::Body::Buffered.wrap(body)

        Protocol::HTTP::Response.new('http/1.1', 200, headers, body)
      end

      def file(path:, content_type:)
        headers = Protocol::HTTP::Headers.new(['content-type', content_type])
        file = File.open(path, 'rb')
        body = Protocol::HTTP::Body::File.new(file)

        Protocol::HTTP::Response.new('http/1.1', 200, headers, body)
      end
    end
  end
end
