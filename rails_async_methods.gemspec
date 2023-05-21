require_relative "lib/rails_async_methods/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_async_methods"
  spec.version     = RailsAsyncMethods::VERSION
  spec.authors     = ["benngarcia"]
  spec.email       = ["beng4606@gmail.com"]
  spec.homepage    = "https://github.com/benngarcia/rails_async_methods"
  spec.summary     = "Quickly, create async callers and receivers for your rails methods, because y'know DRY."
  spec.description = "Utilizes the ActiveJob api to provide async callers and receivers without duplicating code."
  spec.license     = "MIT"

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
