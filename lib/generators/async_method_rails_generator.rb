class AsyncMethodRailsGenerator < Rails::Generators::Base
  desc "This generator creates the base abstract job for the async_method_rails gem"
  def create_abstract_job
    file_path = "app/jobs/async_method_rails/abstract_job.rb"
    return if File.exist? file_path

    create_file file_path,
      <<~FILE
        class AsyncMethodRails::AbstractJob < ApplicationJob
          queue_as :default

          def perform(receiver, method, *args, **kwargs)
            receiver.send(method, *args, **kwargs)
          end
        end
      FILE
  end
end