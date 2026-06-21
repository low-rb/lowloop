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
          body_data = response.body.read || ''
          content_length = body_data.bytesize
        end

        write_status_line(socket, response)
        write_host_header(socket, config)
        write_response_headers(socket, response)
        write_final_headers(socket, content_length, keep_alive)

        if file_body
          IO.copy_stream(response.body.file, socket)
        else
          socket.write(body_data)
        end
      end

      private

      def write_status_line(socket, response)
        socket.puts "#{response.version} #{response.status}\r\n"
      end

      def write_host_header(socket, config)
        socket.puts config.port.nil? ? "Host: #{config.host}\r\n" : "Host: #{config.host}:#{config.port}\r\n"
      end

      def write_response_headers(socket, response)
        response.headers.fields.each do |key, value|
          next if %w[content-length connection].include?(key.to_s.downcase)

          socket.puts "#{key}: #{value}\r\n"
        end
      end

      def write_final_headers(socket, content_length, keep_alive)
        socket.puts "Content-Length: #{content_length}\r\n"
        socket.puts "Connection: #{keep_alive ? 'keep-alive' : 'close'}\r\n"
        socket.puts "\r\n"
      end
    end
  end
end
