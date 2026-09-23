lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "mcc2/version"

Gem::Specification.new do |spec|
  spec.name = "mcc2"
  spec.version = Mcc2::VERSION
  spec.authors = ["Lars Kanis", "Andreas Kosche"]
  spec.email = ["kanis@comcard.de", "kosche@comcard.de"]

  spec.summary = "Layout editor and card printer GUI"
  spec.description = "Layout editor and card printer GUI."
  spec.homepage = "https://gitlab/produktion/mcc2"
  spec.license = "MIT"
  spec.metadata["allowed_push_host"] = "https://ccgems"

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec|features)/}) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.0"

  spec.add_runtime_dependency "nokogiri", "~> 1.4.pre"
  spec.add_runtime_dependency "csv", "~> 3.0"
  spec.add_runtime_dependency "dbf", "~> 1.2"
  spec.add_runtime_dependency "rmagick", ">= 3.0", "< 7.0"
  spec.add_runtime_dependency "ruby-zint", "~> 1.1"
  spec.add_runtime_dependency "fxruby", "~> 1.6.30"
  spec.add_runtime_dependency "ffi-cups", "~> 0.3"
  spec.add_runtime_dependency "win32api4ruby", "~> 0.2"
  spec.add_runtime_dependency "i18n", "~> 1.0"
  spec.add_runtime_dependency 'rsvg2'
  spec.add_runtime_dependency 'cairo'
  spec.add_runtime_dependency 'pango'
  spec.add_runtime_dependency 'ttfunk'

  spec.add_development_dependency "bundler", ">= 1.11"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
