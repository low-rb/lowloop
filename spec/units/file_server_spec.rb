# frozen_string_literal: true

require 'protocol/http/body/file'
require 'low_event'
require 'observers'

require_relative '../../lib/events/file_event'
require_relative '../../lib/servers/file_server'
require_relative '../factories/request_factory'

RSpec.describe Low::FileServer do
  # Specs are run from project root.
  subject(:file_server) { described_class.new(web_root: './public', content_types:) }

  let(:content_types) do
    {
      html: 'text/html',
      txt: 'text/plain',
      jpg: 'image/jpeg',
      jpeg: 'image/jpeg',
      png: 'image/png'
    }
  end
  let(:request_event) { Low::Events::RequestEvent.new(request:) }

  describe '#extension' do
    context 'when the extension is supported' do
      let(:request) { Low::Support::RequestFactory.request(path: '/cave.jpg') }

      it 'returns true for supported extensions' do
        expect(file_server.extension(filepath: request.path)).to eq('jpg')
      end
    end

    context 'when the extension is unsupported' do
      let(:request) { Low::Support::RequestFactory.request(path: '/virus.exe') }

      it 'returns nil for unsupported extensions' do
        expect(file_server.extension(filepath: request.path)).to eq(nil)
      end
    end
  end

  describe '#handle' do
    let(:request) { Low::Support::RequestFactory.request(path: '/cave.jpg') }

    it 'returns a file response' do
      response_event = file_server.handle(event: request_event)
      expect(response_event.response).to have_attributes(body: be_instance_of(Protocol::HTTP::Body::File))
      expect(response_event.response.body.file).to have_attributes(to_path: './public/cave.jpg')
    end

    context 'when the path has query params' do
      let(:request) { Low::Support::RequestFactory.request(path: '/cave.jpg?dimensions=200x200&treasure=ruby') }

      let(:file_event) { Low::Events::FileEvent.new(file:, request:) }
      let(:file) { Low::FileState.new(path: './public/cave.jpg', content_type: content_types[:txt]) }

      before do
        allow(file_server).to receive(:trigger)
      end

      it 'strips the query params' do
        file_server.handle(event: request_event)
        expect(file_server).to have_received(:trigger).with(File, event: file_event)
      end
    end

    context 'when the path does directory traversal' do
      let(:request) { Low::Support::RequestFactory.request(path: '../../etc/passwd.txt') }

      let(:file_event) { Low::Events::FileEvent.new(file:, request:) }
      let(:file) { Low::FileState.new(path: './public/etc/passwd.txt', content_type: content_types[:txt]) }

      before do
        allow(file_server).to receive(:trigger)
      end

      it 'strips the directory traversal segments' do
        file_server.handle(event: request_event)
        expect(file_server).to have_received(:trigger).with(File, event: file_event)
      end
    end
  end
end
