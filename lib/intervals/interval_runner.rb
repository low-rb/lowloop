# frozen_string_literal: true

require 'observers'
require_relative 'interval'

module Low
  module Loop
    # Triggers each observed interval when it's due, checking every second on a thread of its own, so a slow job never
    # holds up the event loop's requests. Jobs run one at a time, and one that runs longer than its interval skips the
    # turns it missed rather than piling up. What a job shares with requests needs to be safe across threads, like a
    # Thread::Queue.
    class IntervalRunner
      def initialize(on_error:)
        @on_error = on_error
      end

      def start
        return if @thread

        @thread = Thread.new do
          loop do
            run_due(Time.now)
            sleep(1 - (Time.now.to_f % 1))
          end
        end
      end

      def stop
        @thread&.kill
        @thread = nil
      end

      # Triggers every observed interval that's due. An error in one is reported, and the rest still run.
      def run_due(now)
        intervals.select { |interval| interval.due?(now) }.each do |interval|
          interval.tick(now)
        rescue StandardError => e
          @on_error.call(e)
        end
      end

      private

      def intervals
        Observers::Keys.keys.keys.grep(Interval)
      end
    end
  end
end
