# frozen_string_literal: true

require 'protocol/http'

require_relative '../../../lib/factories/response_factory'

RSpec.describe Low::Factories::ResponseFactory do
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
  end
end
