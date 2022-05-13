class AsyncExample < ApplicationRecord
  def set_testfield_nil
    update testfield: nil
  end
  async :set_testfield_nil

  def method_with_block(&block)
    if block_given?
      update testfield: block.call
    else
      update testfield: 'No block given'
    end
  end
  async :method_with_block

  def method_with_args_spread_args_and_kwargs(a, *args, **kwargs)
    case a
    when 1
      update testfield: args
    when 2
      update testfield: kwargs
    end
  end
  async :method_with_args_spread_args_and_kwargs

  def method_with_diff_queue
    nil
  end
  async :method_with_diff_queue, queue: :fast

  def method_with_diff_wait_time_and_priority
    nil
  end
  async :method_with_diff_wait_time_and_priority, wait: 1.week, priority: -10

  def method_with_diff_prefix
    nil
  end
  async :method_with_diff_prefix, prefix: :auto_async_

  def method_with_custom_job
    nil
  end
  async :method_with_custom_job, job: ExampleCustomAsyncJob

  def method_with_custom_job_and_args
    nil
  end
  async :method_with_custom_job_and_args, job: :ExampleCustomAsyncJob, queue: :custom
end
