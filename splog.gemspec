# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'splog/version'

Gem::Specification.new do |spec|
  spec.name          = 'splog'
  spec.version       = Splog::VERSION
  spec.authors       = ['Samuel Mendenhall']
  spec.email         = ['Samuel.Mendenhall@gmail.com']
  spec.description   = %q{Parse any log file with yml defined regex rules}
  spec.summary       = %q{Parse any log file with yml defined regex rules}
  spec.homepage      = 'https://github.com/engineersamuel/splog'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # Add runtime dependencies
  spec.add_runtime_dependency 'mongo'
  spec.add_runtime_dependency 'bson_ext'
  spec.add_runtime_dependency 'ruby-progressbar'

  # Add development dependencies
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 2.6'
end
