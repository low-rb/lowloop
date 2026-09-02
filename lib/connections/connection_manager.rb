# frozen_string_literal: true

require 'io/wait'

require_relative 'request_parser'
require_relative '../responses/response_builder'

module Low
  class ConnectionManager
    DEFAULT_KEEP_ALIVE_TIMEOUT = 30
    DEFAULT_REQUEST_TIMEOUT = 10

    def initialize(config:)
      @config = config
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

        # TODO: Handle nil return value; create 500 status code response.
        response_event = Events::RequestEvent.take(request:)
        response = response_event.response

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
  end
end
