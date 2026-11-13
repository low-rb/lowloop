# frozen_string_literal: true

require 'protocol/http'

require_relative '../../../lib/responses/response_factory'

RSpec.describe Low::ResponseFactory do
  describe '.html' do
    subject(:response) { described_class.html(body: 'Hi') }

    it 'sets a readable content-type header' do
      expect(response.headers['content-type']).to eq('text/html')
    end
  end

  describe '.file' do
    subject(:response) { described_class.file(path: './public/cave.jpg', content_type: 'image/jpeg') }

    it 'sets a readable content-type header' do
      expect(response.headers['content-type']).to eq('image/jpeg')
    end

    it 'sets when the file last changed, leaving how it may be cached to the browser' do
      expect(response.headers['last-modified']).to eq(File.mtime('./public/cave.jpg').httpdate)
      expect(response.headers['cache-control']).to be_nil
    end

    context 'with how it may be cached' do
      subject(:response) { described_class.file(path: './public/cave.jpg', content_type: 'image/jpeg', cache_control: 'no-cache') }

      it 'sets its cache-control' do
        expect(response.headers['cache-control']).to eq(['no-cache'])
      end
    end

    after { response.body.close }
  end

  describe '.not_modified' do
    subject(:response) { described_class.not_modified(path: './public/cave.jpg') }

    it "answers 'Not Modified' without a body, by when the file last changed" do
      expect(response).to have_attributes(status: 304, body: nil)
      expect(response.headers['last-modified']).to eq(File.mtime('./public/cave.jpg').httpdate)
    end
  end
end
