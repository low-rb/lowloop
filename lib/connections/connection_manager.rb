# frozen_string_literal: true

require 'io/wait'

require_relative 'request_parser'
require_relative '../responses/response_builder'
require_relative '../responses/response_factory'

module Low
  class ConnectionManager
    DEFAULT_KEEP_ALIVE_TIMEOUT = 30
    DEFAULT_REQUEST_TIMEOUT = 10

    class << self
      # The connections open now. Each is a client like a browser or a proxy such as Caddy, which keeps a few open for
      # its requests. They're all handled on the event loop's thread, so the count needs no lock.
      def open_count
        @open_count ||= 0
      end

      def opened
        @open_count = open_count + 1
      end

      def closed
        @open_count = open_count - 1
      end
    end

    # on_error is called with an error raised while responding to a request, before responding with a 500.
    def initialize(config:, on_error: nil)
      @config = config
      @on_error = on_error
    end

    # Counts the connection as open while its requests are served.
    def handle_connection(socket:)
      self.class.opened
      serve_requests(socket:)
    ensure
      self.class.closed
    end

    # Answers each request on a connection until the client closes it or stops sending.
    def serve_requests(socket:)
      stream = RequestParser.create_stream(socket:)
      keep_alive = true
      version = nil

      while keep_alive
        break unless socket.wait_readable(keep_alive_timeout)

        socket.timeout = request_timeout
        begin
          request = RequestParser.parse(stream:, host: config.host, port: config.port, version:)
        rescue IO::TimeoutError
          break
        ensure
          socket.timeout = nil
        end
        break if request.nil?

        version ||= request.version
        unless headers_valid?(request)
          ResponseBuilder.respond(socket:, response: ResponseFactory.status(code: 400), keep_alive: false)
          break
        end

        keep_alive = keep_alive?(request)

        response = respond_to(request:)

        ResponseBuilder.respond(socket:, response:, keep_alive:)
      end
    end

    def keep_alive?(request)
      tokens = (request.headers['connection'] || []).flat_map do |value|
        value.split(',').map { |token| token.strip.downcase }
      end

      if request.version.to_s.downcase.include?('1.0')
        tokens.include?('keep-alive')
      else
        !tokens.include?('close')
      end
    end

    def keep_alive_timeout
      config.keep_alive_timeout || DEFAULT_KEEP_ALIVE_TIMEOUT
    end

    def request_timeout
      config.request_timeout || DEFAULT_REQUEST_TIMEOUT
    end

    # Headers there can only be one of, like Referer, raise when read if a request repeats them, so it's a bad request.
    def headers_valid?(request)
      request.headers.to_h
      true
    rescue Protocol::HTTP::InvalidHeaderError
      false
    end

    private

    attr_reader :config

    # An error in the application responds with a 500 and keeps the connection, rather than closing it without a response.
    def respond_to(request:)
      Events::RequestEvent.take(request:).response
    rescue StandardError => e
      @on_error&.call(e)
      ResponseFactory.error(error: e, debug: config.debug_mode)
    end
  end
end
