# RailsAsyncMethods
Rails Async Methods is an opinionated gem meant to remove boilerplate while creating asynchronous rails jobs. It provides a declaritive interface for converting any model method into an asychronous method by provided an abstracted wrapper around rails ActiveJob API.

## Usage
```ruby
class User
  def example_method
    # logic...
  end
end
async :example_method
```
This will give you access to ```user_instance.async_example_method```, which when called will use ActiveJob's API to create an ActiveJob with your backend of choice and call the example_method when the job is ran.

One important distinction is that for a method call like
```ruby
def example_method_with_args(a:, b:)
  #logic
end
async :example_method_with_args
```
the ```async_example_method_with_args``` method will have a signature that matches the original method. This makes testing and debugging during development faster, as both sync and async method calls will fail when called instead of silently failing as an active job.

### Options

You can pass the following options to your async declaration.

- prefix: specifies a prefix other than ```async_```, i.e.
```ruby
async :example_method, prefix: :asynchrounous_

user_instance.asynchronous_example_method
```

- job: use a custom job other than the generated ```RailsAsyncMethods::AbstractJob``` - see section on Custom Jobs below i.e.
```ruby
async :example_method, job: CustomExampleMethodJob
```

- ActiveJob configurations
    - queue: specify a custom queue
    - wait_until: specify a date for the job to run at
    - wait: give an amount of time for the job to wait until executing
    - priority: delayed job priority
```ruby
async :example_method, queue: :fast, wait_until: 1.week.from_now, wait: 1.week, priority: 1
```

## Installation
Add this line to your application's Gemfile:

```ruby
gem "rails_async_methods"
```

And then execute:
```bash
$ bundle
```

Then, run the generator
```bash
$ rails generate rails_async_methods
```

Or install it yourself as:
```bash
$ gem install rails_async_methods
```

## Extras

### Custom Jobs
While you can implement any custom job, and have it implement the perform method with this signature.
```ruby
def perform(receiver, method, *args, **kwargs)
  receiver.send(method, *args, **kwargs)
end
```

I would instead recommend inherting from the generated ActiveJob, i.e.

```ruby
class RailsAsyncMethods::CustomJob < RailsAsyncMethods::AbstractJob
  around_perform :do_special_thing

  private
  def do_special_thing
    # Special Things
  end
end
```

## Contributing
Contributions Welcome! Please create an issue first, and then fork and create a PR. 

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Why?
You don't need to move 1-2 LOC out of your model. If it's larger, use a service object. Either way, your controllers and requests should be interacting with resources typically. They should not need to know about Jobs/Service/Other Design Pattern implementations of interacting with your resources. In this line of thinking, most calls that interact with a resource should be called on that resource's model. Thus, Job's that wrap 1-2 LOC or a call to a Service object are unneccesary boilerplate.

So, either write your minimal logic in the model, or use whatever refactoring you deem necessary, but leave the model as the entry point for interacting with the resource. Then, declare that method as Async when you need fit.

I told you this gem is opinionated.

Also, the existing alternatives override the method's name, leading to confusion as what appears to be synchronous was made asyncronous. 
