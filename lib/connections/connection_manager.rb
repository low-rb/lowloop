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

      while keep_alive
        break unless socket.wait_readable(keep_alive_timeout)

        socket.timeout = request_timeout
        begin
          request = RequestParser.parse(stream:, host: config.host, port: config.port)
        rescue IO::TimeoutError
          break
        ensure
          socket.timeout = nil
        end
        break if request.nil?

        unless headers_valid?(request)
          ResponseBuilder.respond(socket:, response: ResponseFactory.status(code: 400), keep_alive: false)
          break
        end

        keep_alive = keep_alive?(request)

        response = respond_to(request:)

        ResponseBuilder.respond(socket:, response:, keep_alive:)
      end
    end

    # The Connection header is read from the request's fields, as reading it with "request.headers['connection']" would
    # index and parse every header. Its tokens, like "keep-alive, Upgrade", are matched in any case.
    def keep_alive?(request)
      if request.version.to_s.include?('1.0')
        connection?(request, KEEP_ALIVE_TOKEN)
      else
        !connection?(request, CLOSE_TOKEN)
      end
    end

    KEEP_ALIVE_TOKEN = /(?:\A|,)\s*keep-alive\s*(?:,|\z)/i
    CLOSE_TOKEN = /(?:\A|,)\s*close\s*(?:,|\z)/i

    # Header names are ASCII, so they're compared with casecmp, as casecmp? folds Unicode case into new strings.
    def connection?(request, token)
      request.headers.fields.any? do |name, value|
        name = name.to_s
        name.length == 10 && name.casecmp('connection') == 0 && value.to_s.match?(token) # rubocop:disable Style/NumericPredicate
      end
    end

    # Each header name in lowercase, made once for each name, as most requests send the same few. Only so many are kept,
    # as a client can send any name.
    DOWNCASED = {} # rubocop:disable Style/MutableConstant
    DOWNCASED_LIMIT = 1000

    def downcased(name)
      DOWNCASED[name] || (DOWNCASED.size < DOWNCASED_LIMIT ? DOWNCASED[name.dup.freeze] = name.downcase.freeze : name.downcase)
    end

    def keep_alive_timeout
      config.keep_alive_timeout || DEFAULT_KEEP_ALIVE_TIMEOUT
    end

    def request_timeout
      config.request_timeout || DEFAULT_REQUEST_TIMEOUT
    end

    # Headers there can only be one of, like Referer, raise when read if a request repeats them, so it's a bad request.
    # They're those without a policy for joining them in Protocol::HTTP, which is checked by name, rather than indexing
    # and parsing every header with "to_h" before anything reads them.
    def headers_valid?(request)
      seen = nil
      request.headers.fields.each do |field|
        key = downcased(field.first.to_s)
        next if Protocol::HTTP::Headers::POLICY[key]

        seen ||= {}
        return false if seen.key?(key)

        seen[key] = true
      end
      true
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
