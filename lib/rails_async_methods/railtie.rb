# frozen_string_literal: true

module RailsAsyncMethods
  class Railtie < Rails::Railtie
    initializer "rails_async_methods.active_job_serializers" do
      ActiveSupport.on_load(:active_job) do
        RailsAsyncMethods.register_serializers!
      end
    end
  end
end
