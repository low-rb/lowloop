# frozen_string_literal: true

require 'io/stream'
require 'async/http'
require 'protocol/http'

module Low
  class RequestParser
    include LowType

    class << self
      def parse(socket: TCPSocket, host: String, port: Integer) -> { ::Protocol::HTTP::Request }
        stream = IO::Stream(socket)
        protocol = Async::HTTP::Protocol::HTTP.default.protocol_for(stream)

        method, path, = parse_request(stream:)
        headers = parse_headers(stream:)
        body = parse_body(stream:, method:)

        ::Protocol::HTTP::Request.new('http', "#{host}:#{port}", method, path, protocol::VERSION, headers, body)
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
        request_line = stream.gets || raise(StandardError, 'EOF')

        method, full_path, _http_version = request_line.strip.split(' ', 3)
        path, query = full_path.split('?', 2)

        [method, full_path, path, query]
      end

      # TODO: Handle namespaced stream type "IO:Stream".
      def parse_headers(stream:) -> { ::Protocol::HTTP::Headers }
        fields = []

        while (line = stream.gets.strip)
          break if line.strip.empty?

          key, value = line.split(/:\s/, 2)
          fields << [key, value]
        end

        ::Protocol::HTTP::Headers.new(fields)
      end

      def parse_body(stream:, method:)
        return nil unless %w[POST PUT].include?(method)

        stream.read
      end
    end
  end
end
