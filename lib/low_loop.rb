# frozen_string_literal: true

require 'async'
require 'socket'
require 'low_type'
require 'low_event'
require 'observers'

require_relative 'factories/response_factory'
require_relative 'requests/request_parser'
require_relative 'responses/response_builder'

module Low
  class Loop
    include Observers

    attr_reader :config

    def initialize(config:, dependencies: [])
      @config = config

      dependencies.each do |dependency|
        observers << dependency
      end

      observers.push(self, action: :mirror) if config.mirror_mode
    end

    def start
      server = start_server

      Fiber.set_scheduler(Async::Scheduler.new)

      Fiber.schedule do
        loop do
          socket = server.accept

          Fiber.schedule do
            request = RequestParser.parse(socket:, host: config.host, port: config.port)
            response_event = take(event: Events::RequestEvent.new(request:))
            response = response_event.response

            ResponseBuilder.respond(config:, socket:, response:)
          rescue StandardError => e
            puts e.message
          ensure
            socket&.close
          end
        end
      end
    end

    def start_server
      puts "Starting server @ #{config.host}:#{config.port}" unless config.matrix_mode

      server = TCPServer.new(config.host, config.port)
      server.listen(10)
      server
    end

    # Fallback mode for when there's no dependencies and you want to know that the server is still working.
    def mirror(event:)
      request = event.request
      response = Factories::ResponseFactory.html(body: "Thank you for visiting #{request.path} with body: '#{request.body}'")
      Events::ResponseEvent.new(response:)
    end

    # Consider LowLoop a value object in the context of Observers (there can only be one).
    def ==(other) = other.class == self.class
    def eql?(other) = self == other
    def hash = [self.class].hash
  end
end

LowLoop = Low::Loop
