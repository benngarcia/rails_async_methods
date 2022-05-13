class ExampleCustomAsyncJob < ApplicationJob
  queue_as :default

  around_perform :example

  def perform(receiver, method, *args, **kwargs)
    receiver.send(method, *args, **kwargs)
  end

  private

  def example
    true
  end
end
