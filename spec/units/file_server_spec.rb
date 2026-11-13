# frozen_string_literal: true

require 'protocol/http/body/file'
require 'lowevent'
require 'observers'

require_relative '../../lib/events/file_event'
require_relative '../../lib/servers/file_server'
require_relative '../factories/request_factory'

RSpec.describe Low::FileServer do
  subject(:file_server) { described_class.new(web_root:, content_types:) }

  # Specs are run from project root.
  let(:web_root) { File.expand_path('public', Dir.pwd) }
  let(:content_types) do
    {
      html: 'text/html',
      txt: 'text/plain',
      jpg: 'image/jpeg',
      jpeg: 'image/jpeg',
      png: 'image/png',
      svg: 'image/svg+xml'
    }
  end
  let(:request_event) { Low::Events::RequestEvent.new(request:) }

  describe '#extension' do
    context 'when the extension is supported' do
      let(:request) { Low::Support::RequestFactory.request(path: '/cave.jpg') }

      it 'returns true for supported extensions' do
        expect(file_server.extension(file_path: request.path)).to eq('jpg')
      end
    end

    context 'when the extension is unsupported' do
      let(:request) { Low::Support::RequestFactory.request(path: '/virus.exe') }

      it 'returns nil for unsupported extensions' do
        expect(file_server.extension(file_path: request.path)).to eq(nil)
      end
    end
  end

  describe '#request' do
    let(:request) { Low::Support::RequestFactory.request(path: '/cave.jpg') }

    # FileEvent.take is not stubbed and that's important. We're testing the wiring too.
    it 'returns a file response' do
      response_event = file_server.request(event: request_event)
      expect(response_event.response).to have_attributes(body: be_instance_of(Protocol::HTTP::Body::File))
      expect(response_event.response.body.file).to have_attributes(to_path: File.expand_path('cave.jpg', web_root))
    end

    context 'when the browser kept a copy of the file' do
      let(:changed) { File.mtime(File.expand_path('cave.jpg', web_root)) }
      let(:request) { Low::Support::RequestFactory.request(path: '/cave.jpg', headers: [['if-modified-since', kept.httpdate]]) }

      context "and it hasn't changed since" do
        let(:kept) { changed }

        it "answers 'Not Modified', without the file" do
          expect(file_server.request(event: request_event).response).to have_attributes(status: 304, body: nil)
        end
      end

      context 'and it has changed since' do
        let(:kept) { changed - 60 }

        it 'answers with the file' do
          response = file_server.request(event: request_event).response
          expect(response).to have_attributes(status: 200, body: be_instance_of(Protocol::HTTP::Body::File))
          response.body.close
        end
      end
    end

    context "with the app's cache-control for every file" do
      subject(:file_server) { described_class.new(web_root:, content_types:, cache_control: 'no-cache') }

      it 'sends it with each file' do
        response = file_server.request(event: request_event).response
        expect(response.headers['cache-control']).to eq(['no-cache'])
        response.body.close
      end
    end

    context "with the app's cache-control for each extension" do
      subject(:file_server) { described_class.new(web_root:, content_types:, cache_control: { jpg: 'max-age=60', html: 'no-cache' }) }

      it "sends a file's extension's" do
        response = file_server.request(event: request_event).response
        expect(response.headers['cache-control']).to eq(['max-age=60'])
        response.body.close
      end
    end

    context 'when the path has query params' do
      let(:request) { Low::Support::RequestFactory.request(path: '/cave.jpg?dimensions=200x200&treasure=ruby') }
      let(:file) { Low::States::FileState.new(path: File.expand_path('cave.jpg', web_root), content_type: content_types[:jpg]) }

      before do
        allow(Low::Events::FileEvent).to receive(:take)
      end

      it 'strips the query params' do
        file_server.request(event: request_event)
        expect(Low::Events::FileEvent).to have_received(:take).with(file:, request:)
      end
    end

    context 'when the path has encoded spaces' do
      let(:request) { Low::Support::RequestFactory.request(path: '/Event%20Tree.svg') }
      let(:file) { Low::States::FileState.new(path: File.expand_path('Event Tree.svg', web_root), content_type: content_types[:svg]) }

      before do
        allow(Low::Events::FileEvent).to receive(:take)
      end

      it 'decodes the path' do
        file_server.request(event: request_event)
        expect(Low::Events::FileEvent).to have_received(:take).with(file:, request:)
      end
    end

    context 'when the path does directory traversal' do
      let(:request) { Low::Support::RequestFactory.request(path: '../../etc/passwd.txt') }
      let(:file) { Low::States::FileState.new(path: './public/etc/passwd.txt', content_type: content_types[:txt]) }

      before do
        allow(Low::Events::FileEvent).to receive(:take)
      end

      it 'raises argument error' do
        expect { file_server.request(event: request_event) }.to raise_error(ArgumentError, 'Path escapes the specified root!')
      end
    end
  end
end
