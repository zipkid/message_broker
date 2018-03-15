
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'message_broker/version'

Gem::Specification.new do |spec|
  spec.name          = 'message_broker'
  spec.version       = MessageBroker::VERSION
  spec.authors       = ['Stefan - Zipkid - Goethals']
  spec.email         = ['stefan@zipkid.eu']
  spec.summary       = 'Message Broker'
  spec.description   = 'Message Broker'
  spec.homepage      = 'https://github.com/zipkid/message_broker'
  spec.license       = 'MIT'

  raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.' unless spec.respond_to?(:metadata)
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spec.add_runtime_dependency 'websocket-driver'
  spec.add_runtime_dependency 'slack-rtmapi2', '~> 2'
end
