# frozen_string_literal: true

module Low
  class FileState
    attr_reader :path, :content_type

    def initialize(path:, content_type:)
      @path = path
      @content_type = content_type
    end
  end
end
