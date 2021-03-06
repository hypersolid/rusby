# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rusby/version'

Gem::Specification.new do |spec|
  spec.name          = "rusby"
  spec.version       = Rusby::VERSION
  spec.authors       = ["Alexander Krasnoschekov"]
  spec.email         = ["akrasnoschekov@gmail.com"]

  spec.summary       = %q{Ruby to Rust transpiler for simple performance-oriented methods.}
  spec.homepage      = "https://github.com/rambler-digital-solutions/rusby"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"

  spec.add_runtime_dependency 'method_source'
  spec.add_runtime_dependency 'ffi'
  spec.add_runtime_dependency 'hashie'
  spec.add_runtime_dependency 'colorize'
  spec.add_runtime_dependency 'parser'

  spec.require_paths = [
    "lib"
  ]
end
