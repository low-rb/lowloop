# frozen_string_literal: true

class MockMatrix
  def initialize(stream_pool:)
    @stream_pool = stream_pool
  end

  def render(screen_size:)
    @stream_pool.each do |stream_id, stream_tree|

    end
  end
end
