# frozen_string_literal: true

require 'protocol/url'

require_relative '../events/file_event'
require_relative '../responses/file_response'
require_relative '../states/file_state'

module Low
  class FileServer
    include LowType
    include Observers

    def initialize(web_root:, content_types:, cache_control: nil)
      @web_root = web_root
      @content_types = content_types.transform_keys(&:to_s)
      @cache_control = cache_control

      observers(Events::FileEvent) << FileResponse
    end

    def extension(file_path:)
      extension = File.extname(file_path).delete_prefix('.')

      return nil if extension == ''
      return nil unless @content_types.key?(extension)

      extension
    end

    def cache_control(extension)
      return @cache_control unless @cache_control.is_a?(Hash)

      @cache_control.transform_keys(&:to_s)[extension]
    end

    def request(event: Events::RequestEvent)
      file_path = event.request.path

      return nil unless file_path.include?('.')

      url = Protocol::URL[file_path]
      extension = extension(file_path: url.path.to_s)
      return nil if extension.nil?

      file_path = url.local_path(@web_root)
      file = States::FileState.new(path: file_path, content_type: @content_types[extension], cache_control: cache_control(extension))

      Events::FileEvent.take(file:, request: event.request)
    end
  end
end
