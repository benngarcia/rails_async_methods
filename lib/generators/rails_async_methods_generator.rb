class RailsAsyncMethodsGenerator < Rails::Generators::Base
  desc "This generator creates the base abstract job for the rails_async_methods gem"
  def create_abstract_job
    file_path = "app/jobs/rails_async_methods/abstract_job.rb"
    return if File.exist? file_path

    create_file file_path,
      <<~FILE
        class RailsAsyncMethods::AbstractJob < ApplicationJob
          queue_as :default

          def perform(receiver, method, *args, **kwargs)
            receiver.public_send(method, *args, **kwargs)
          end
        end
      FILE
  end
end