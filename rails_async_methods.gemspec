require_relative "lib/rails_async_methods/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_async_methods"
  spec.version     = RailsAsyncMethods::VERSION
  spec.authors     = ["benngarcia"]
  spec.email       = ["beng4606@gmail.com"]
  spec.homepage    = "https://github.com/benngarcia/rails_async_methods"
  spec.summary     = "[DEPRECATED] Quickly create async callers and receivers for your Rails methods."
  spec.description = "DEPRECATED: rails_async_methods is sunset. See https://github.com/benngarcia/rails_async_methods for details and the security-hardened rewrite branch."
  spec.license     = "MIT"

  spec.post_install_message = <<~MSG
    ================================================================================
    [DEPRECATED] rails_async_methods is sunset and no longer actively maintained.

    Releases <= 0.2.x contain known security and correctness issues (including
    module_eval parameter shadowing and un-allowlisted job dispatch).

    - Production apps: use standard ActiveJob / ApplicationJob classes directly.
    - Reference fix: https://github.com/benngarcia/rails_async_methods/tree/rewrite
    ================================================================================
  MSG

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/benngarcia/rails_async_methods/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "activesupport"
  spec.add_dependency "rails", ">= 7.0.2.4"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "sidekiq"
end
