# RailsAsyncMethods (`rewrite` branch — Sunset Reference Implementation)

> **Deprecated / Sunset:** `rails_async_methods` is no longer actively maintained.
> This `rewrite` branch is a security-hardened, zero-`eval` from-scratch implementation kept as a clean reference if you want to vendor or fork the pattern in your own Rails 7.2+ / 8.0+ application.

## What Changed vs. `0.2.x`

- **Zero `eval` / zero parameter shadowing RCE**: replaces `module_eval` + `binding.local_variable_get` with a pure Ruby 3.3+ `Signature` validator over `Method#parameters` that preserves default arguments intact.
- **Defense-in-depth allowlist**: both enqueue (`Proxy`) and worker execution (`Dispatcher#perform`) verify that the target class opted in and explicitly declared the method async before calling `public_send`.
- **Zero global `Object` pollution**: drops `Object#async`, `Object#to_active_job`, and automatic `ActiveRecord::Base` patching in favor of opt-in `include RailsAsyncMethods` + a `BasicObject` proxy.
- **Transaction-safe & Zeitwerk-safe**: enables ActiveJob's `enqueue_after_transaction_commit` by default, requires `Proc` for declaration-level `wait_until:`, and stores job class names as strings resolved at enqueue time.
- **Class methods, stateless services, and batching**: supports `async_class_method` via a dedicated `ClassTargetSerializer`, custom `ActiveJob::Base` / `ApplicationJob` subclasses via `include RailsAsyncMethods::Dispatcher`, and `ActiveJob.perform_all_later` via `async_job`.

## Usage

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include RailsAsyncMethods
end

class User < ApplicationRecord
  async_method :send_welcome_email, queue: :mailers
  def send_welcome_email(template: :default)
    UserMailer.welcome(self, template: template).deliver_now
  end

  async_method def sync_stripe_customer
    Stripe::CustomerSync.call(self)
  end

  async_class_method :prune_inactive,
    queue: :maintenance,
    wait_until: -> { Time.current.tomorrow.change(hour: 3) }
  def self.prune_inactive(older_than:)
    where(last_seen_at: ...older_than).delete_all
  end
end

# Stateless service with custom ApplicationJob (retry_on, Solid Queue limits_concurrency, etc.)
class Billing::ChargeInvoice
  include RailsAsyncMethods

  async_class_method :call, job: "BillingDispatchJob"
  def self.call(invoice)
    # ...
  end
end

class BillingDispatchJob < ApplicationJob
  include RailsAsyncMethods::Dispatcher
  retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5
end

# Call sites
user.async.send_welcome_email
user.async(wait: 5.minutes).send_welcome_email(template: :vip)
User.async.prune_inactive(older_than: 90.days.ago)
Billing::ChargeInvoice.async.call(invoice)

# Batch enqueueing (Rails 7.1+)
ActiveJob.perform_all_later(users.map { |u| u.async_job.send_welcome_email })
```

### Testing

```ruby
class UserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include RailsAsyncMethods::TestHelper

  test "enqueues welcome email" do
    assert_async_method_enqueued(@user, :send_welcome_email, kwargs: { template: :vip }, queue: "mailers") do
      @user.async.send_welcome_email(template: :vip)
    end
  end
end
```

## License

Available as open source under the [MIT License](MIT-LICENSE).
