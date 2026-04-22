# frozen_string_literal: true

require 'io/stream'
require 'async/http'
require 'protocol/http'

module Low
  class RequestParser
    include LowType

    class << self
      def create_stream(socket)
        IO::Stream(socket)
      end

      def parse(stream:, host:, port:, version: nil)
        version ||= Async::HTTP::Protocol::HTTP.default.protocol_for(stream)::VERSION

        result = parse_request(stream:)
        return nil unless result

        method, full_path, = result
        headers = parse_headers(stream:)
        body = parse_body(stream:, method:, headers:)

        ::Protocol::HTTP::Request.new('http', "#{host}:#{port}", method, full_path, version, headers, body)
      end

      private

      # HTTP Request format:
      #
      # :verb :path HTTP/1.1\r\n
      # :header_1\r\n
      # :header_2\r\n
      # :header_3\r\n
      # \r\n
      # :body
      #
      # TODO: Handle type for namespaced "IO:Stream".
      def parse_request(stream:)
        request_line = stream.gets
        return nil if request_line.nil?

        request_line = request_line.strip
        return nil if request_line.empty?

        method, full_path, _http_version = request_line.split(' ', 3)
        path, query = full_path.split('?', 2)

        [method, full_path, path, query]
      end

      # TODO: Handle namespaced stream type "IO:Stream".
      def parse_headers(stream:) -> { ::Protocol::HTTP::Headers }
        fields = []

        while (line = stream.gets)
          line = line.strip
          break if line.empty?

          key, value = line.split(/:\s/, 2)
          fields << [key, value]
        end

        ::Protocol::HTTP::Headers.new(fields)
      end

      def parse_body(stream:, method:, headers:)
        return nil unless %w[POST PUT PATCH].include?(method)

        content_length = headers['content-length']&.first&.to_i
        return nil unless content_length&.positive?

        stream.read(content_length)
      end
    end
  end
end
