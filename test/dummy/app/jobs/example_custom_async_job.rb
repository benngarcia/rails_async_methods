class ExampleCustomAsyncJob < RailsAsyncMethods::AbstractJob
  queue_as :default

  before_perform :example
  def example
    true
  end
end
