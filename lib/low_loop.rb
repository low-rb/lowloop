# frozen_string_literal: true

require 'async'
require 'paint'
require 'socket'
require 'low_type'
require 'low_event'
require 'observers'

require_relative 'factories/response_factory'
require_relative 'connections/connection_manager'
require_relative 'servers/file_server'
require_relative 'support/low_frame'

class LowLoop
  include Observers

  attr_reader :config

  def initialize(config:, router: nil, renderer: nil, show_output: true)
    @config = config
    @connection_manager = Low::ConnectionManager.new(config:)
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
      render_frame(task)

      loop do
        socket = server.accept

        task.async do
          @connection_manager.handle_connection(socket:)
        rescue StandardError => e
          render_error(e)
        ensure
          socket&.close
        end
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

  def start_server
    puts "Starting server @ #{config.host}:#{config.port}" unless config.matrix_mode

    server = TCPServer.new(config.host, config.port)
    server.listen(10)
    server
  end

  def render_frame(task)
    return unless @frame.renderer

    task.async do
      loop do
        @frame.render
        sleep 0.1 # 10fps
      end
    end
  end

  def render_error(error)
    puts "\nException:"
    puts Paint[error.message, :red]
    puts ''

    return unless @config.debug_mode

    Fiber.blocking do
      puts Paint[error.backtrace.join("\n"), :blue]
      puts ''
      puts 'Press ENTER to continue...'
      gets
    end
  end
end
