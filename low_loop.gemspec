# frozen_string_literal: true

require_relative 'lib/version'

Gem::Specification.new do |spec|
  spec.name = 'low_loop'
  spec.version = Low::Loop::VERSION
  spec.authors = ['maedi']
  spec.email = ['maediprichard@gmail.com']

  spec.summary = 'An event-driven event loop'
  spec.description = 'An asynchronous server that creates events for your event-driven application to use'
  spec.homepage = 'https://github.com/low-rb/low_loop'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/low-rb/low_loop/src/branch/main'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('lib/**/*')
  end

  spec.require_paths = ['lib']
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }

  spec.add_dependency 'async'
  spec.add_dependency 'async-http'
  spec.add_dependency 'io-stream'
  spec.add_dependency 'protocol-http'
  spec.add_dependency 'protocol-url'

  spec.add_dependency 'low_event'
  spec.add_dependency 'low_type', '~> 1.0'
end
