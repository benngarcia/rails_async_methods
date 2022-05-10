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
end
