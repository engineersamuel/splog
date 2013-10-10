# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'splog/version'

Gem::Specification.new do |spec|
  spec.name          = 'splog'
  spec.version       = Splog::VERSION
  spec.authors       = ['Samuel Mendenhall']
  spec.email         = ['Samuel.Mendenhall@gmail.com']
  spec.description   = %q{Parse any log file with user defined regular rules}
  spec.summary       = %q{Parse any log file with user defined regular rules}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # Add runtime dependencies
  spec.add_runtime_dependency 'awesome_print'

  # Add development dependencies
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 2.6'
end
