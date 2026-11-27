# frozen_string_literal: true

module Low
  class ResponseBuilder
    # Room for the status line and headers of most responses.
    HEAD_CAPACITY = 1024
    # Headers set from the response itself, rather than from the node's headers.
    FINAL_HEADERS = %w[content-length connection].freeze
    KEEP_ALIVE = "Connection: keep-alive\r\n\r\n"
    CLOSE = "Connection: close\r\n\r\n"
    # A status code's text, like "200", made once for each code.
    STATUSES = (100..599).to_h { [it, it.to_s.freeze] }.freeze

    class << self
      # TODO: Use Async wherever we can where it doesn't have "Task" requirement.
      def respond(socket:, response:, keep_alive: true)
        file_body = response.body.respond_to?(:file)
        chunks = body_chunks(response.body) unless file_body
        content_length = file_body ? response.body.file.size : chunks.sum(&:bytesize)

        # Build the whole response in one string, sized up front so it isn't copied as it grows, then write once, as
        # every socket write is a syscall.
        head = String.new(capacity: HEAD_CAPACITY + (file_body ? 0 : content_length))
        write_status_line(head, response)
        write_response_headers(head, response)
        write_final_headers(head, content_length, keep_alive)

        if file_body
          socket.write(head)
          IO.copy_stream(response.body.file, socket)
        else
          # As bytes, so a body in any encoding can follow headers in any other.
          chunks.each { head.append_as_bytes(it) }
          socket.write(head)
        end
      ensure
        response.body.close if file_body
      end

      private

      # A buffered body's chunks as they are, rather than joined into a copy. Any other body is read, and a response
      # can have no body, like a node returning "Status[201]".
      def body_chunks(body)
        return body.chunks if body.is_a?(Protocol::HTTP::Body::Buffered)

        [body&.join].compact
      end

      # Each part is appended as it is, rather than interpolated into a new string first.
      def write_status_line(head, response)
        status = response.status
        head << response.version.to_s << ' ' << (STATUSES[status] || status.to_s) << "\r\n"
      end

      def write_response_headers(head, response)
        response.headers.fields.each do |key, value|
          key = key.to_s
          next if FINAL_HEADERS.any? { key.casecmp?(it) }

          head << key << ': ' << value.to_s << "\r\n"
        end
      end

      def write_final_headers(head, content_length, keep_alive)
        head << 'Content-Length: ' << content_length.to_s << "\r\n"
        head << (keep_alive ? KEEP_ALIVE : CLOSE)
      end
    end
  end
end
