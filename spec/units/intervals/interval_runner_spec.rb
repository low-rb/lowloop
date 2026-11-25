# frozen_string_literal: true

require 'lowevent'
require 'observers'
require_relative '../../../lib/intervals/interval_runner'

RSpec.describe Low::Loop::IntervalRunner do
  subject(:runner) { described_class.new(on_error: ->(error) { errors << error }) }

  let(:errors) { [] }
  let(:now) { Time.new(2026, 11, 24, 12, 0, 0) }

  # Something that observes an interval and records each tick.
  def job(interval, &work)
    Class.new do
      extend Observers
      observe interval
      define_singleton_method(:tick, &work)
    end
  end

  before { Observers::Keys.reset }

  it 'ticks the observers of each interval that is due' do
    ticks = []
    job(Low::Loop::Interval[every_second: 2]) { ticks << :fast }
    job(Low::Loop::Interval[every_minute: 1]) { ticks << :slow }
    [0, 1, 2, 60].each { |second| runner.run_due(now + second) }
    expect(ticks).to eq(%i[fast fast slow])
  end

  it 'ticks every observer of the same schedule' do
    ticks = []
    job(Low::Loop::Interval[every_minute: 1]) { ticks << :one }
    job(Low::Loop::Interval[every_second: 60]) { ticks << :two }
    runner.run_due(now)
    runner.run_due(now + 60)
    expect(ticks).to eq(%i[one two])
  end

  it 'reports an error in one interval and still runs the rest' do
    ticks = []
    job(Low::Loop::Interval[every_second: 5]) { raise 'Burnt' }
    job(Low::Loop::Interval[every_second: 7]) { ticks << :baked }
    runner.run_due(now)
    runner.run_due(now + 35)
    expect([errors.map(&:message).first.include?('Burnt'), ticks]).to eq([true, [:baked]])
  end

  it 'skips the turns a slow job missed instead of catching up' do
    ticks = []
    job(Low::Loop::Interval[every_second: 1]) { ticks << :tick }
    runner.run_due(now)
    runner.run_due(now + 1)
    runner.run_due(now + 10)
    expect(ticks.size).to eq(2)
  end

  it 'ticks on a thread of its own' do
    threads = Queue.new
    job(Low::Loop::Interval[every_second: 1]) { threads << Thread.current }
    runner.start
    ticked_on = threads.pop(timeout: 3)
    runner.stop
    expect([ticked_on.nil?, ticked_on == Thread.current]).to eq([false, false])
  end
end
