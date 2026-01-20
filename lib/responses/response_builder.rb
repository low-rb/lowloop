# frozen_string_literal: true

module Low
  class ResponseBuilder
    class << self
      # TODO: Use Async wherever we can where it doesn't have "Task" requirement.
      def respond(config:, socket:, response:)
        socket.puts "#{response.version} #{response.status}\r\n"
        socket.puts config.port.nil? ? "Host: #{config.host}\r\n" : "Host: #{config.host}:#{config.port}\r\n"

        response.headers.fields.each_slice(2) do |key, value|
          socket.puts "#{key}: #{value}\r\n"
        end

        socket.puts "\r\n"

        if response.body.respond_to?(:file)
          IO.copy_stream(response.body.file, socket)
        else
          socket.puts(response.body.read)
        end

        socket.close
      end
    end
  end
end
