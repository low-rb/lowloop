# frozen_string_literal: true

require 'lowevent'
require_relative '../../../lib/connections/connection_manager'
require_relative '../../factories/request_factory'

RSpec.describe Low::ConnectionManager do
  subject(:manager) { described_class.new(config:, on_error: ->(error) { errors << error }) }

  let(:config) { Struct.new(:debug_mode).new(debug_mode) }
  let(:debug_mode) { false }
  let(:errors) { [] }
  let(:request) { Low::Support::RequestFactory.request(path: '/') }

  context 'when the application raises an error' do
    subject(:response) { manager.send(:respond_to, request:) }

    before do
      allow(Low::Events::RequestEvent).to receive(:take).and_raise(RuntimeError, 'Rudolph <broke>')
    end

    it 'responds with a 500' do
      expect(response.status).to eq(500)
      expect(response.body.join).to eq('<h1>500 Internal Server Error</h1>')
    end

    it 'reports the error' do
      response
      expect(errors.map(&:message)).to eq(['Rudolph <broke>'])
    end

    context 'with debug mode' do
      let(:debug_mode) { true }

      it 'shows the escaped error' do
        expect(response.body.join).to include('<pre>RuntimeError: Rudolph &lt;broke&gt;')
      end
    end
  end

  describe '#headers_valid?' do
    it 'accepts a request with each header once' do
      expect(manager.headers_valid?(request)).to be(true)
    end

    it 'refuses a request repeating a header there can only be one of' do
      request = Low::Support::RequestFactory.request(path: '/', headers: [%w[referer http://a.test], %w[referer http://b.test]])

      expect(manager.headers_valid?(request)).to be(false)
    end
  end
  describe '.open_count' do
    it "counts a connection while it's handled and not after, even when handling it fails" do
      before_count = described_class.open_count
      during = nil
      allow(Low::RequestParser).to receive(:create_stream) do
        during = described_class.open_count
        raise IOError
      end
      expect { manager.handle_connection(socket: nil) }.to raise_error(IOError)
      expect([during - before_count, described_class.open_count - before_count]).to eq([1, 0])
    end
  end
end
