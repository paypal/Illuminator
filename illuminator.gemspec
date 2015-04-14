# coding: utf-8
lib = File.expand_path('../gem/lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'illuminator/version'

Gem::Specification.new do |spec|
  spec.name          = "illuminator"
  spec.version       = Illuminator::VERSION
  spec.licenses      = ['Apache 2.0']
  spec.authors       = ["Ian Katz", "Boris Erceg"]
  spec.email         = ["iakatz@paypal.com"]

  spec.summary       = %q{iOS CI test runner for Illuminator}
  spec.homepage      = "http://github.com/paypal/illuminator"

  spec.files         =  Dir['gem/**/*.*'].reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["gem/lib"]

  if spec.respond_to?(:metadata)
    # spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
  end

  spec.add_development_dependency "bundler", ">= 1.3.6"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "json"
  spec.add_runtime_dependency "colorize"
  spec.add_runtime_dependency "xcpretty"
  spec.add_runtime_dependency "dnssd"
end
