# frozen_string_literal: true

require 'protocol/url'

require_relative '../events/file_event'
require_relative '../responses/file_response'
require_relative '../states/file_state'

module Low
  class FileServer
    include LowType
    include Observers

    def initialize(web_root:, content_types:)
      @web_root = web_root
      @content_types = content_types.transform_keys(&:to_s)

      observers(Events::FileEvent) << FileResponse
    end

    def extension(filepath:)
      extension = File.extname(filepath).delete_prefix('.')

      return nil if extension == ''
      return nil unless @content_types.key?(extension)

      extension
    end

    # TODO: Define type: Events::RequestEvent
    def handle(event:)
      filepath = Protocol::URL[event.request.path].path

      extension = extension(filepath:)
      return nil if extension.nil?

      file = States::FileState.new(path: safe_path(filepath), content_type: @content_types[extension])

      Events::FileEvent.trigger(file:, request: event.request)
    end

    private

    def safe_path(path)
      safe_path = path.split('/').reject { |segment| ['.', '..'].include?(segment) }.join('/')
      File.join(@web_root, safe_path)
    end
  end
end
