# frozen_string_literal: true

require 'socket'
require_relative '../../../lib/lowloop'

RSpec.describe Low::RequestParser do
  def parse(raw)
    client, server = UNIXSocket.pair
    client.write(raw)
    client.close_write

    described_class.parse(stream: IO::Stream(server), host: 'localhost', port: 4133)
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

  context 'with an HTTP/1.0 request' do
    it 'reads its version from the request line' do
      expect(parse("GET / HTTP/1.0\r\nHost: localhost\r\n\r\n").version).to eq('HTTP/1.0')
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

  context 'with a query string' do
    let(:request) { parse("GET /search?q=rye HTTP/1.1\r\nHost: localhost\r\n\r\n") }

    it 'reads the method, the whole path and the authority' do
      expect([request.method, request.path, request.authority]).to eq(['GET', '/search?q=rye', 'localhost:4133'])
    end
  end

  context 'with a header without a colon' do
    let(:request) { parse("GET / HTTP/1.1\r\nX-Broken\r\nAccept: text/html\r\n\r\n") }

    it 'keeps it with an empty value and reads the next header' do
      expect(request.headers.fields).to eq([['X-Broken', ''], ['Accept', 'text/html']])
    end
  end
end
