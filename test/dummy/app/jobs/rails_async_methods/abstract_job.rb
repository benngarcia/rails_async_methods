class RailsAsyncMethods::AbstractJob < ApplicationJob
  queue_as :default

  def perform(receiver, method, *args, **kwargs)
    receiver.public_send(method, *args, **kwargs)
  end
end
