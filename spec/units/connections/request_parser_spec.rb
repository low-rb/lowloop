# frozen_string_literal: true

require 'socket'
require_relative '../../../lib/lowloop'

RSpec.describe Low::RequestParser do
  def parse(raw)
    client, server = UNIXSocket.pair
    client.write(raw)
    client.close_write

    described_class.parse(stream: IO::Stream(server), host: 'localhost', port: 4133, version: 'HTTP/1.1')
  end

  context 'with a request body' do
    let(:request) { parse("POST /feedback HTTP/1.1\r\nHost: localhost\r\nContent-Length: 9\r\n\r\nnose=red!") }

    it 'parses the body into a readable body' do
      expect(request.body).to be_a(Protocol::HTTP::Body::Readable)
      expect(request.body.join).to eq('nose=red!')
    end
  end

  context 'without a request body' do
    let(:request) { parse("POST /feedback HTTP/1.1\r\nHost: localhost\r\n\r\n") }

    it 'has no body' do
      expect(request.body).to be_nil
    end
  end

  context 'with a GET request' do
    let(:request) { parse("GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 3\r\n\r\nabc") }

    it 'ignores the body' do
      expect(request.body).to be_nil
    end
  end

  context 'with an empty header and one without a space after its colon' do
    let(:request) { parse("GET / HTTP/1.1\r\nHost:localhost\r\nAccept-Language:\r\n\r\n") }

    it 'reads their values' do
      expect(request.headers['host']).to eq('localhost')
      expect(request.headers['accept-language']).to eq([])
    end
  end
end
