# frozen_string_literal: true

require 'async'
require 'io/wait'
require 'paint'
require 'socket'
require 'low_type'
require 'low_event'
require 'observers'

require_relative 'factories/response_factory'
require_relative 'requests/request_parser'
require_relative 'responses/response_builder'
require_relative 'servers/file_server'
require_relative 'support/low_frame'

class LowLoop
  include Observers

  DEFAULT_KEEP_ALIVE_TIMEOUT = 30
  DEFAULT_REQUEST_TIMEOUT = 10

  attr_reader :config

  def initialize(config:, router: nil, renderer: nil, show_output: true)
    @config = config
    @frame = LowFrame.new(renderer:, fps: 10, show_output:)

    Low::Events::RequestEvent.define do |observers|
      observers << Low::FileServer.new(web_root: config.web_root, content_types: config.content_types)
      observers << router if router
      observers.push(self, action: :mirror) if config.mirror_mode
    end
  end

  def start
    server = start_server

    Async do |task|
      # Background task.
      task.async do
        loop do
          @frame.render if @frame.renderer
          sleep 0.1 # 10fps
        end
      end

      # Request handler.
      loop do
        socket = server.accept

        task.async do
          handle_connection(socket)
        rescue StandardError => e
          render_error(e)
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

  def render
    Async do
      loop do
        @frame.render
      end
    end
  end

  # Fallback mode for when there's no dependencies and you want to know that the server is still working.
  def mirror(event:)
    request = event.request
    response = Low::Factories::ResponseFactory.html(body: "Thank you for visiting #{request.path} with body: '#{request.body}'")
    Low::Events::ResponseEvent.new(response:)
  end

  # Consider LowLoop a value object in the context of Observers (there can only be one).
  def ==(other) = other.class == self.class
  def eql?(other) = self == other
  def hash = [self.class].hash

  private

  def render_error(e)
    puts "\nException:"
    puts Paint[e.message, :red]
    puts ''

    if @config.debug_mode
      Fiber.blocking do
        puts Paint[e.backtrace.join("\n"), :blue]
        puts ''
        puts 'Press ENTER to continue...'
        gets
      end
    end
  end

  def handle_connection(socket)
    stream = Low::RequestParser.create_stream(socket:)
    keep_alive = true
    version = nil

    while keep_alive
      break unless socket.wait_readable(keep_alive_timeout)

      socket.timeout = request_timeout
      begin
        request = Low::RequestParser.parse(stream:, host: config.host, port: config.port, version:)
      rescue IO::TimeoutError
        break
      ensure
        socket.timeout = nil
      end
      break if request.nil?

      version ||= request.version
      keep_alive = keep_alive?(request)

      # TODO: Handle nil return value; create 500 status code response.
      response_event = Low::Events::RequestEvent.take(request:)
      response = response_event.response

      Low::ResponseBuilder.respond(config:, socket:, response:, keep_alive:)
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
end
