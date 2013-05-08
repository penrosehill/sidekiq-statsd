require "sidekiq"
require "active_support"
require "active_support/core_ext"

require "sidekiq/throttler/version"
require "sidekiq/throttler/statsd"

module Sidekiq
  ##
  # Sidekiq StatsD is a middleware to increment your worker executions counter (success and failures).
  #
  class Throttler
    ##
    # Initializes the middleware with options.
    #
    # @param [Hash] options The options to initialize the StatsD client.
    # @option options [String] :env ("production")
    # @option options [String] :prefix ("worker")
    # @option options [String] :host ("localhost")
    # @option options [String] :port ("8125")
    def initialize options={}
      @options = options
    end

    ##
    # Increments the metrics.
    #
    # @param worker [Sidekiq::Worker] The worker the job belongs to.
    # @param msg [Hash] The job message.
    # @param queue [String] The current queue.
    def call worker, msg, queue
      stastd = Sidekiq::Throttler::Statsd.new @options
      yield
      stastd.increment [worker.class.name, "success"].join(".")
    rescue => e
      stastd.increment [worker.class.name, "failure"].join(".")
      raise e
    end

  end # Throttler
end # Sidekiq
