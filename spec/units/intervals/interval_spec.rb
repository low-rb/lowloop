# frozen_string_literal: true

require 'lowevent'
require_relative '../../../lib/intervals/interval'

RSpec.describe Low::Loop::Interval do
  let(:noon) { Time.new(2026, 11, 24, 12, 0, 0) }

  it 'counts its schedule in seconds' do
    expect([described_class[every_second: 30], described_class[every_minute: 3], described_class[every_hour: 2],
            described_class[every_day: 1]].map(&:seconds)).to eq([30, 180, 7200, 86_400])
  end

  it 'lists what observes any interval with each object once' do
    Observers::Keys.reset
    minutely = Class.new { include Observers }
    daily = Class.new { include Observers }
    minutely.observe described_class[every_minute: 1]
    daily.observe described_class[every_day: 1]
    daily.observe '/about'

    expect(described_class.observers.to_a.map(&:object)).to eq([minutely, daily])
  end

  it "starts an event tree of its own each tick kept apart from the app's" do
    expect([described_class[every_minute: 1].starts_event_tree?, described_class[every_minute: 1].internal?]).to eq([true, true])
  end

  it 'needs one unit to count in' do
    expect { described_class[at_hour: 2] }.to raise_error(ArgumentError)
    expect { described_class[every_second: 1, every_minute: 1] }.to raise_error(ArgumentError)
  end

  it 'is the same interval wherever the same schedule is written' do
    expect([described_class[every_minute: 3] == described_class[every_second: 180],
            described_class[every_minute: 3].hash == described_class[every_second: 180].hash,
            described_class[every_minute: 3] == described_class[every_minute: 3, at_hour: 2]]).to eq([true, true, false])
  end

  it 'is due the first time, then once its seconds have passed since it was triggered' do
    interval = described_class[every_minute: 1]
    due = [interval.due?(noon)]
    allow(interval).to receive(:trigger)
    interval.tick(noon)
    expect(due + [interval.due?(noon + 59), interval.due?(noon + 60)]).to eq([true, false, true])
  end

  it 'is only due in its hour' do
    interval = described_class[every_minute: 3, at_hour: 2]
    expect([interval.due?(noon), interval.due?(Time.new(2026, 11, 24, 2, 30, 0))]).to eq([false, true])
  end
end
