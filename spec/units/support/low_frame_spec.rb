# frozen_string_literal: true

require_relative '../../../lib/support/low_frame'

RSpec.describe LowFrame do
  subject(:low_frame) { described_class.new(renderer:, fps:, debug: true) }

  let(:renderer) { double(Object, render: nil) }

  describe '#render' do
    after do
      low_frame.reset
    end

    context 'when 2 FPS' do
      let(:fps) { 2 }

      it 'renders 4 times' do
        start_time = Time.now.to_i

        loop do
          low_frame.render
          break if (Time.now.to_i - start_time) > 1 # 1 second has passed.
        end

        # Once for the initial render as soon as called, 3 times because integer precision reduces frame duration?
        expect(renderer).to have_received(:render).exactly(4).times
      end
    end
  end
end
