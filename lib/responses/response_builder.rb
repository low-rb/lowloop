# frozen_string_literal: true

module Low
  class ResponseBuilder
    # Room for the status line and headers of most responses.
    HEAD_CAPACITY = 1024

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

      def write_status_line(head, response)
        head << "#{response.version} #{response.status}\r\n"
      end

      def write_response_headers(head, response)
        response.headers.fields.each do |key, value|
          next if %w[content-length connection].include?(key.to_s.downcase)

          head << "#{key}: #{value}\r\n"
        end
      end

      def write_final_headers(head, content_length, keep_alive)
        head << "Content-Length: #{content_length}\r\n"
        head << "Connection: #{keep_alive ? 'keep-alive' : 'close'}\r\n"
        head << "\r\n"
      end
    end
  end
end
