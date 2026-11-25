# frozen_string_literal: true

require 'lowevent'

module Low
  module Loop
    # A schedule to observe to run code periodically, like "observe Interval[every_minute: 3]". LowLoop triggers each
    # observed interval when it's due with the "tick" action, on a worker thread of its own, so a slow job never holds up
    # requests. Its turns follow the clock like :00 :03 :06 so restarting the app doesn't move them. With "at_hour: 2"
    # it's only due during that hour of the day.
    #
    #   Interval[every_second: 30]
    #   Interval[every_minute: 3, at_hour: 2]
    class Interval < Low::Event
      UNITS = { every_second: 1, every_minute: 60, every_hour: 3600, every_day: 86_400 }.freeze

      attr_reader :seconds, :at_hour, :triggered_at

      def self.[](at_hour: nil, **every)
        unit, count = every.first
        raise ArgumentError, "An interval needs one of #{UNITS.keys.join(', ')}" unless every.size == 1 && UNITS.key?(unit)

        new(seconds: UNITS[unit] * count, at_hour:)
      end

      # Nodes observe an interval like "Interval[every_minute: 1]" rather than this class so they're who observes it.
      def self.observers(key = nil)
        return super if key

        Observers.of_keys { |each_key| each_key.is_a?(Interval) }
      end

      # The interval is its own key, so its observers are the ones observing the same schedule.
      def initialize(seconds:, at_hour: nil)
        super(key: self, action: :tick)

        @seconds = seconds
        @at_hour = at_hour
        @triggered_at = nil
      end

      # Each tick starts a tree of its own so a job's events are let go like a request's.
      def starts_event_tree?
        true
      end

      # Its trees are kept apart so ticks never push the app's requests out of the event pool.
      def internal?
        true
      end

      # Whether a turn has started since its last. The turn it's first seen in started before the app did so it waits for
      # the next. It's not due outside its hour.
      def due?(now)
        @turn ||= turn_at(now)
        return false if at_hour && now.hour != at_hour

        turn_at(now) > @turn
      end

      # Triggers its observers, marking the turn it's in as run.
      def tick(now = Time.now)
        @triggered_at = now
        @turn = turn_at(now)
        trigger
      end

      # Whether one of its turns starts at that second.
      def starts_turn?(time)
        (local_seconds(time) % seconds).zero?
      end

      # The same schedule observed in two places is one interval, so both are triggered together.
      def ==(other) = other.is_a?(Interval) && other.seconds == seconds && other.at_hour == at_hour
      def eql?(other) = self == other
      def hash = [self.class, seconds, at_hour].hash

      private

      # How many turns have passed since the epoch on the server's clock.
      def turn_at(time)
        local_seconds(time) / seconds
      end

      # Counts in the server's time zone so a day's turns start at its midnight.
      def local_seconds(time)
        time.to_i + time.utc_offset
      end
    end
  end
end
