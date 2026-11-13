# frozen_string_literal: true

require 'cgi'
require 'time'
require 'protocol/http'
require 'protocol/http/body/file'

module Low
  class ResponseFactory
    class << self
      def html(body:)
        headers = Protocol::HTTP::Headers.new([['content-type', 'text/html']])
        body = Protocol::HTTP::Body::Buffered.wrap(body.strip)
        Protocol::HTTP::Response.new('HTTP/1.1', 200, headers, body)
      end

      def file(path:, content_type:, cache_control: nil)
        headers = Protocol::HTTP::Headers.new([['content-type', content_type], *cache_headers(path, cache_control)])
        file = File.open(path, 'rb')
        body = Protocol::HTTP::Body::File.new(file)
        Protocol::HTTP::Response.new('HTTP/1.1', 200, headers, body)
      end

      def not_modified(path:, cache_control: nil)
        headers = Protocol::HTTP::Headers.new(cache_headers(path, cache_control))
        Protocol::HTTP::Response.new('HTTP/1.1', 304, headers, nil)
      end

      def cache_headers(path, cache_control)
        headers = [['last-modified', File.mtime(path).httpdate]]
        headers << ['cache-control', cache_control] if cache_control
        headers
      end

      # Shows the error and where it happened in debug mode (or show a 500 status).
      def error(error:, debug: false)
        headers = Protocol::HTTP::Headers.new([['content-type', 'text/html']])
        trace = CGI.escapeHTML("#{error.class}: #{error.message}\n\n#{error.backtrace&.join("\n")}") if debug

        html = <<~HTML.strip
          <h1>500 Internal Server Error</h1>
          #{"<pre>#{trace}</pre>" if debug}
        HTML

        Protocol::HTTP::Response.new('HTTP/1.1', 500, headers, Protocol::HTTP::Body::Buffered.wrap(html))
      end

      def status(code:)
        headers = Protocol::HTTP::Headers.new([['content-type', 'text/html']])
        Protocol::HTTP::Response.new('HTTP/1.1', code, headers, nil)
      end
    end
  end
end
