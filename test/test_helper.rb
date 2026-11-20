# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "active_support/core_ext/numeric/time"
require "active_record"
require "active_job"
require "active_job/test_helper"
require "global_id"
require "rails_async_methods"
require "rails_async_methods/test_helper"

GlobalID.app = "rails-async-methods-test"
ActiveJob::Base.include(ActiveJob::EnqueueAfterTransactionCommit) if defined?(ActiveJob::EnqueueAfterTransactionCommit)
ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Logger.new(nil)

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.text :last_call
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  include GlobalID::Identification
  include RailsAsyncMethods
end

class User < ApplicationRecord
  async_method :record_call, queue: :default
  def record_call(subject = "Welcome", urgent: true, retries: 3)
    update_column(:last_call, JSON.generate([subject, urgent, retries]))
  end

  async_method def ping
    update_column(:last_call, "pong")
  end

  async_method :tricky_param_names
  def tricky_param_names(method_name, argument, binding, parsed_method_arguments)
    update_column(:last_call, JSON.generate([method_name, argument, binding, parsed_method_arguments]))
  end

  async_method :options
  def options
    update_column(:last_call, "model_options_called")
  end

  async_method :display
  def display(label)
    update_column(:last_call, "display:#{label}")
  end

  async_method :notify, queue: ->(user) { user.name == "vip" ? :high : :low }
  def notify(message)
    update_column(:last_call, message)
  end

  async_method :scheduled_via_proc, wait_until: -> { Time.at(1_900_000_000).utc }
  def scheduled_via_proc
    update_column(:last_call, "scheduled")
  end

  async_method :delayed_call, wait: 10.minutes
  def delayed_call
    update_column(:last_call, "delayed")
  end

  async_method :protected_work
  async_method :private_work

  async_class_method :bulk_cleanup, queue: :maintenance
  def self.bulk_cleanup(older_than:)
    where("id > ?", older_than).update_all(last_call: "cleaned")
  end

  def undeclared_method
    update_column(:last_call, "should_never_run")
  end

  protected

  def protected_work
    update_column(:last_call, "protected")
  end

  private

  def private_work
    update_column(:last_call, "private")
  end
end

class AdminUser < User
  def notify(message, channel: :email)
    update_column(:last_call, "#{channel}:#{message}")
  end

  async_method :admin_only
  def admin_only
    update_column(:last_call, "admin_only")
  end
end

class StatelessService
  include RailsAsyncMethods

  cattr_accessor :calls, default: []

  async_class_method :call, queue: :services
  def self.call(value, mode: :fast)
    calls << [value, mode]
  end
end

class GlobalIdPoro
  include GlobalID::Identification
  include RailsAsyncMethods

  STORE = {}

  attr_reader :id, :events

  def self.find(id)
    STORE.fetch(id.to_s)
  end

  def initialize(id)
    @id = id.to_s
    @events = []
    STORE[@id] = self
  end

  async_method :push
  def push(item)
    @events << item
  end
end

class StatefulPoro
  include RailsAsyncMethods

  async_method :run
  def run
    :ok
  end
end

class CustomDispatchJob < ActiveJob::Base
  include RailsAsyncMethods::Dispatcher

  cattr_accessor :around_ran, default: false

  around_perform do |_job, block|
    self.class.around_ran = true
    block.call
  end
end

class PlainObject
  def hello
    "world"
  end
end
