# frozen_string_literal: true

require 'io/console'

class LowFrame
  attr_reader :screen_size, :renderer

  def initialize(renderer:, fps: 10, show_output: true)
    @renderer = renderer
    @show_output = show_output

    # Millisecond duration of each frame. We lose a small amount of precision dropping the decimal.
    @frame_time = ((1.0 / fps) * 1000).to_i
    @last_frame = nil

    setup if renderer && show_output
  end

  def render
    return unless @last_frame.nil? || (current_timestamp - @last_frame) >= @frame_time

    @last_frame = current_timestamp
    @renderer.render(screen_size: @screen_size)
  end

  def setup
    print "\e[?25l" # Hide cursor.
    system 'clear'

    resize

    Signal.trap('WINCH') do
      resize
    end

    Signal.trap('INT') do
      print "\e[?25h\e[0m" # Show cursor and reset colors.
      system 'clear'
      exit
    end
  end

  def resize
    row_count, column_count = IO.console.winsize
    @screen_size = { row_count:, column_count: }
  end

  private

  def current_timestamp
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
  end
end
