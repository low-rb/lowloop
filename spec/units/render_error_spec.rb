# frozen_string_literal: true

require 'async'
require_relative '../../lib/support/config_loader'
require_relative '../../lib/lowloop'

RSpec.describe LowLoop do
  subject(:lowloop) { described_class.new(config:, renderer: double(Object, render: nil), show_output: false) }

  let(:config) { Low::ConfigLoader.load('./spec/fixtures/config.yaml').tap { it.matrix_mode = matrix_mode } }
  let(:error) { RuntimeError.new('Rudolph broke').tap { it.set_backtrace(['nodes.rb:1']) } }
  let(:stdin) { IO.pipe }

  around do |example|
    original_stdin = $stdin
    $stdin = stdin.first
    example.run
  ensure
    $stdin = original_stdin
  end

  before do
    allow(lowloop).to receive(:puts)
  end

  context 'with matrix mode' do
    let(:matrix_mode) { true }

    it 'pauses the frame until ENTER is pressed, without blocking other tasks' do
      Async do |task|
        lowloop.send(:render_error, error)
        expect(lowloop.frame.paused?).to be(true)

        other_task_ran = task.async { true }.wait
        expect(other_task_ran).to be(true)

        stdin.last.puts
        100.times { lowloop.frame.paused? ? sleep(0.01) : break }
        expect(lowloop.frame.paused?).to be(false)
      end
    end
  end

  context 'without matrix mode' do
    let(:matrix_mode) { false }

    it 'does not wait for ENTER' do
      Async { lowloop.send(:render_error, error) }

      expect(lowloop.frame.paused?).to be(false)
    end
  end
end
