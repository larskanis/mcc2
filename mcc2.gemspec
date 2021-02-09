# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mcc2/version'

Gem::Specification.new do |spec|
  spec.name          = "mcc2"
  spec.version       = Mcc2::VERSION
  spec.authors       = ["Lars Kanis", 'Andreas Kosche']
  spec.email         = ["kanis@comcard.de", 'kosche@comcard.de']

  spec.summary       = %q{Layout editor and card printer GUI}
  spec.description   = %q{Layout editor and card printer GUI.}
  spec.homepage      = "http://comdb1/projektverwaltung/projects/mcc2"
  spec.license       = "MIT"
  spec.metadata['allowed_push_host'] = "http://ccgems"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ['>= 2.0', '< 4.0']

  spec.add_runtime_dependency "nokogiri", "~> 1.4.pre"
  spec.add_runtime_dependency "dbf", "~> 1.2"
  spec.add_runtime_dependency "rmagick", ">= 3.0", "< 5.0"
  spec.add_runtime_dependency "barby", "~> 0.5"
  spec.add_runtime_dependency "rqrcode", ">= 0.4", "< 2.0"
  spec.add_runtime_dependency "fxruby", "~> 1.6.30"

  spec.add_development_dependency "bundler", ">= 1.11", "<= 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
