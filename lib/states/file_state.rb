# frozen_string_literal: true

module Low
  module States
    FileState = Data.define(:path, :content_type, :cache_control) do
      def initialize(path:, content_type:, cache_control: nil) = super
    end
  end
end
