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

  it 'waits for the next turn of the clock after it is first seen' do
    interval = described_class[every_minute: 1]
    allow(interval).to receive(:trigger)
    due = [interval.due?(noon), interval.due?(noon + 59), interval.due?(noon + 60)]
    interval.tick(noon + 60)
    expect(due + [interval.due?(noon + 61), interval.due?(noon + 120)]).to eq([false, false, true, false, true])
  end

  it 'follows the clock rather than when the app started' do
    interval = described_class[every_minute: 10]
    seen = interval.due?(noon + 180)
    expect([seen, interval.due?(noon + 599), interval.due?(noon + 600)]).to eq([false, false, true])
  end

  it 'is only due in its hour' do
    interval = described_class[every_minute: 3, at_hour: 2]
    one_am = Time.new(2026, 11, 24, 1, 59, 0)
    expect([interval.due?(one_am), interval.due?(one_am + 60), interval.due?(noon)]).to eq([false, true, false])
  end

  it 'says which seconds start its turns' do
    interval = described_class[every_minute: 10]
    expect([interval.starts_turn?(noon), interval.starts_turn?(noon + 60), interval.starts_turn?(noon + 600)])
      .to eq([true, false, true])
  end

  it 'notes whether each turn ran or failed or was skipped' do
    interval = described_class[every_minute: 1]
    interval.due?(noon)
    allow(interval).to receive(:trigger)
    interval.tick(noon + 60)
    allow(interval).to receive(:trigger).and_raise('Burnt')
    expect { interval.tick(noon + 180) }.to raise_error('Burnt')
    expect([noon, noon + 60, noon + 120, noon + 180, noon + 240].map { interval.outcome_at(it, now: noon + 200) })
      .to eq([nil, :ran, :skipped, :failed, nil])
  end

  it 'is running while its observers are' do
    interval = described_class[every_minute: 1]
    during = nil
    allow(interval).to receive(:trigger) { during = interval.outcome_at(noon) }
    interval.tick(noon)
    expect(during).to eq(:running)
  end
end
