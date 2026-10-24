# frozen_string_literal: true

require 'io/wait'

require_relative 'request_parser'
require_relative '../responses/response_builder'
require_relative '../responses/response_factory'

module Low
  class ConnectionManager
    DEFAULT_KEEP_ALIVE_TIMEOUT = 30
    DEFAULT_REQUEST_TIMEOUT = 10

    # on_error is called with an error raised while responding to a request, before responding with a 500.
    def initialize(config:, on_error: nil)
      @config = config
      @on_error = on_error
    end

    def handle_connection(socket:)
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
        keep_alive = keep_alive?(request)

        response = respond_to(request:)

        ResponseBuilder.respond(config:, socket:, response:, keep_alive:)
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
