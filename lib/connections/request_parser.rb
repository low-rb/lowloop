# frozen_string_literal: true

require 'io/stream'
require 'async/http'
require 'protocol/http'

module Low
  class RequestParser
    include LowType

    # The methods with a body to read. A constant, as a %w[] literal makes a new array of new strings every time.
    BODY_METHODS = %w[POST PUT PATCH].freeze

    class << self
      def create_stream(socket: TCPSocket) -> { IO::Stream::Generic }
        IO::Stream(socket)
      end

      def parse(stream: IO::Stream::Generic, host: String, port: Integer) -> { ::Protocol::HTTP::Request | nil }
        result = parse_request(stream:)
        return nil unless result

        method, full_path, version = result
        headers = parse_headers(stream:)
        body = parse_body(stream:, method:, headers:)

        ::Protocol::HTTP::Request.new('http', authority(host, port), method, full_path, version, headers, body)
      end

      # Like "127.0.0.1:4133", made once, as a server's host and port don't change.
      def authority(host, port)
        last_host, last_port, authority = @authority
        return authority if last_host == host && last_port == port

        authority = "#{host}:#{port}".freeze
        @authority = [host, port, authority].freeze
        authority
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
      # The line is read into a new string so it's stripped in place. A line without a version is an HTTP/1.0 client's.
      def parse_request(stream: IO::Stream::Generic)
        request_line = stream.gets || return

        request_line.strip!
        return nil if request_line.empty?

        method_end = request_line.index(' ') || request_line.length
        path_end = request_line.index(' ', method_end + 1) || request_line.length

        version = request_line[path_end + 1..]
        version = 'HTTP/1.0' if version.nil? || version.empty?
        [request_line[0, method_end], request_line[method_end + 1, path_end - method_end - 1], version]
      end

      def parse_headers(stream: IO::Stream::Generic) -> { ::Protocol::HTTP::Headers }
        fields = []

        # Sometimes returns nil which represents a client disconnect mid-request.
        while (line = stream.gets)
          line.strip!
          break if line.empty?

          # A value can be empty, like "Accept-Language:", or follow the colon without a space.
          colon = line.index(':')
          next fields << [line, +''] unless colon

          value = line[colon + 1, line.length]
          value.strip!
          fields << [line[0, colon], value]
        end

        ::Protocol::HTTP::Headers.new(fields)
      end

      def parse_body(stream: IO::Stream::Generic, method: String, headers: ::Protocol::HTTP::Headers)
        return nil unless BODY_METHODS.include?(method)

        # A single value header like content-length is a String.
        content_length = headers['content-length'].to_i
        return nil unless content_length.positive?

        ::Protocol::HTTP::Body::Buffered.wrap(stream.read(content_length))
      end
    end
  end
end
