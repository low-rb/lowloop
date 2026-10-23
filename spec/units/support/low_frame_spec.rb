# frozen_string_literal: true

require_relative '../../../lib/support/low_frame'

RSpec.describe LowFrame do
  subject(:low_frame) { described_class.new(renderer:, fps:, show_output: true) }

  let(:renderer) { double(Object, render: nil) }

  describe '#render' do
    context 'when 2 FPS' do
      let(:fps) { 2 }

      it 'renders 3 to 4 times' do
        start_time = Time.now.to_i

        loop do
          low_frame.render
          break if (Time.now.to_i - start_time) > 1 # 1 second has passed.
        end

        # Once for the initial render, then 2 to 3 times because integer precision reduces frame duration?
        expect(renderer).to have_received(:render).at_least(3).times.at_most(5).times
      end
    end
  end

  describe '#resize' do
    let(:fps) { 10 }

    context 'when there is no real console (e.g. no TTY, a headless/backgrounded process)' do
      before { allow(IO).to receive(:console).and_return(nil) }

      it 'does not raise' do
        expect { low_frame }.not_to raise_error
      end

      it 'falls back to a default screen size instead of leaving it unset' do
        expect(low_frame.screen_size).to eq(row_count: 24, column_count: 80)
      end
    end

    context 'when there is a real console' do
      let(:console) { instance_double(IO, winsize: [40, 120]) }

      before { allow(IO).to receive(:console).and_return(console) }

      it 'uses the real console size' do
        expect(low_frame.screen_size).to eq(row_count: 40, column_count: 120)
      end
    end
  end
end
