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

        socket.puts "#{response.version} #{response.status}\r\n"
        socket.puts config.port.nil? ? "Host: #{config.host}\r\n" : "Host: #{config.host}:#{config.port}\r\n"

        response.headers.fields.each_slice(2) do |key, value|
          next if %w[content-length connection].include?(key.to_s.downcase)

          socket.puts "#{key}: #{value}\r\n"
        end

        socket.puts "Content-Length: #{content_length}\r\n"
        socket.puts "Connection: #{keep_alive ? 'keep-alive' : 'close'}\r\n"
        socket.puts "\r\n"

        if file_body
          IO.copy_stream(response.body.file, socket)
        else
          socket.write(body_data)
        end
      end
    end
  end
end
