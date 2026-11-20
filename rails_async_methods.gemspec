# frozen_string_literal: true

require_relative "lib/rails_async_methods/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_async_methods"
  spec.version     = RailsAsyncMethods::VERSION
  spec.authors     = ["benngarcia"]
  spec.email       = ["beng4606@gmail.com"]
  spec.homepage    = "https://github.com/benngarcia/rails_async_methods"
  spec.summary     = "Authorized, zero-eval async method dispatch for Rails via ActiveJob."
  spec.description = "Opt-in declarative async method dispatch for ActiveRecord/GlobalID models and stateless Ruby classes using ActiveJob."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["source_code_uri"]       = "#{spec.homepage}/tree/rewrite"
  spec.metadata["bug_tracker_uri"]       = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"]         = "#{spec.homepage}/blob/rewrite/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.post_install_message = <<~MSG
    [DEPRECATED] rails_async_methods is sunset and no longer actively maintained.
    See https://github.com/benngarcia/rails_async_methods for migration notes.
  MSG

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*.rb", "MIT-LICENSE", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "activejob", ">= 7.2", "< 9.0"
  spec.add_dependency "activesupport", ">= 7.2", "< 9.0"
  spec.add_dependency "globalid", ">= 1.0", "< 2.0"
end
