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

    it 'refuses one repeated in another case, like Host and host' do
      request = Low::Support::RequestFactory.request(path: '/', headers: [%w[Host a.test], %w[host b.test]])

      expect(manager.headers_valid?(request)).to be(false)
    end

    it 'accepts a header that can be repeated, like Accept-Language, without indexing every header' do
      request = Low::Support::RequestFactory.request(path: '/', headers: [%w[Accept-Language en], %w[accept-language fr]])
      allow(request.headers).to receive(:to_h).and_call_original

      expect(manager.headers_valid?(request)).to be(true)
      expect(request.headers).not_to have_received(:to_h)
    end
  end
  describe '#keep_alive?' do
    def request_with(connection, version: 'HTTP/1.1')
      headers = connection ? [['Connection', connection]] : []
      Low::Support::RequestFactory.request(path: '/', headers:).tap { it.version = version }
    end

    it 'keeps an HTTP/1.1 connection alive unless it asks to close' do
      expect(manager.keep_alive?(request_with(nil))).to be(true)
      expect(manager.keep_alive?(request_with('Close'))).to be(false)
      expect(manager.keep_alive?(request_with('keep-alive, close'))).to be(false)
    end

    it 'keeps an HTTP/1.0 connection alive only when it asks to' do
      expect(manager.keep_alive?(request_with(nil, version: 'HTTP/1.0'))).to be(false)
      expect(manager.keep_alive?(request_with('Keep-Alive', version: 'HTTP/1.0'))).to be(true)
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
