# frozen_string_literal: true

module Low
  class ResponseBuilder
    class << self
      # TODO: Use Async wherever we can where it doesn't have "Task" requirement.
      def respond(config:, socket:, response:, keep_alive: true)
        file_body = response.body.respond_to?(:file)

        if file_body
          content_length = response.body.file.size
        else
          # A response can have no body, like a node returning "Status[201]", and "join" reads every chunk of a body.
          body_data = response.body&.join || ''
          content_length = body_data.bytesize
        end

        # Build the whole head in memory then write once, as every socket write is a syscall.
        head = +''
        write_status_line(head, response)
        write_host_header(head, config)
        write_response_headers(head, response)
        write_final_headers(head, content_length, keep_alive)

        if file_body
          socket.write(head)
          IO.copy_stream(response.body.file, socket)
        else
          socket.write(head << body_data)
        end
      end

      private

      def write_status_line(head, response)
        head << "#{response.version} #{response.status}\r\n"
      end

      def write_host_header(head, config)
        head << (config.port.nil? ? "Host: #{config.host}\r\n" : "Host: #{config.host}:#{config.port}\r\n")
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
