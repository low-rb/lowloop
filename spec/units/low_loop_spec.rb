# frozen_string_literal: true

require 'benchmark'

require 'net/http'
require 'uri'
require 'async'
require 'async/http/internet'
require 'protocol/http'
require 'socket'

require 'low_event'
require_relative '../../lib/factories/response_factory'
require_relative '../../lib/low_loop'
require_relative '../factories/request_factory'
require_relative '../fixtures/router'

RSpec.describe LowLoop do
  subject(:low_loop) { described_class.new(config:) }

  let(:config) do
    config = Struct.new(:host, :port, :matrix_mode, :mirror_mode)
    config.new('127.0.0.1', 4133, false, false)
  end
  let(:router) do
    # In practice LowLoop observes the router, but because "before(:all)" can't stub ":router" then we inverse the observe.
    Router.new.tap { |router| router.observe(low_loop) }
  end

  let(:request_event) { Low::Events::RequestEvent.new(request:) }
  let(:request) { Low::Support::RequestFactory.request(path: '/') }
  let(:response) { Low::ResponseFactory.html(body: 'Hi') }

  let(:endpoint) { "http://#{host}:#{port}" }
  let(:host) { '127.0.0.1' }
  let(:port) { 4133 }
  let(:client) { Async::HTTP::Internet.new }
  # Or could be more direct:
  # endpoint = Async::HTTP::Endpoint["http://#{host}:#{port}"]
  # client = Async::HTTP::Client.new(endpoint)

  def response_event(response:, delay_duration: 0)
    sleep delay_duration if delay_duration > 0
    Low::Events::ResponseEvent.new(response:)
  end

  before do
    allow(router).to receive(:handle).and_return(response_event(response:))
  end

  context 'without event loop' do
    it 'responds to a request' do
      expect(low_loop.take(event: request_event)).to be_instance_of(Low::Events::ResponseEvent)
    end
  end

  # TODO: Debugging is made easier when non-async so add a synchronous debug mode and test this.
  # context 'when in debug mode (synchronous)'

  context 'when in async mode (asynchronous)' do
    before(:all) do
      config = Struct.new(:host, :port, :matrix_mode, :mirror_mode)

      # When thread wont die run:
      # lsof -i :4133
      # kill -9 <pid>
      @server = Thread.new do
        described_class.new(config: config.new('127.0.0.1', 4133, false, false)).start
      end

      sleep 0.1
    end

    before do
      # Delay response to mimic IO.
      allow(router).to receive(:handle) do
        response_event(response:, delay_duration: 1)
      end
    end

    context 'when the request is a path' do
      let(:response) { Low::ResponseFactory.html(body: 'Hello') }

      it 'responds with a buffered body' do
        expect(Net::HTTP.get_response(URI.parse(endpoint)).body.strip).to eq('Hello')
      end
    end

    context 'when the request is a filepath' do
      # TODO: Currently stubbing response through router but should stub file server and its response as this.
      let(:response) { Low::ResponseFactory.file(path: './public/cave.jpg', content_type: 'jpg') }

      it 'responds with a file body' do
        http_response = Net::HTTP.get_response(URI.parse(endpoint))

        expect(http_response.code).to eq('200')
        expect(http_response.content_type).to eq('jpg')
        expect(http_response.body).to eq(File.binread('./public/cave.jpg'))
      end
    end

    context 'with blocking IO' do
      let(:request_count) { 100 }

      it 'responds to requests asynchronously' do
        duration = Benchmark.measure do
          Async do
            tasks = Array.new(request_count).map do
              Async do
                response = client.get(endpoint)
                response.read
                response.close
              end
            end

            tasks.map(&:result)
          end
        end.real

        expect(router).to have_received(:handle).exactly(request_count).times
        expect(duration).to be < 1.1
      end
    end

    after(:all) do
      @server.kill
    end
  end
end
