class AsyncMethodRails::AbstractJob < ApplicationJob
  queue_as :default

  def perform(receiver, method, *args, **kwargs)
    receiver.send(method, *args, **kwargs)
  end
end
