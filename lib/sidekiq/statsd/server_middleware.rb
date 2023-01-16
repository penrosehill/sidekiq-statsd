# encoding: utf-8

module Sidekiq::Statsd
  ##
  # Sidekiq StatsD is a middleware to track worker execution metrics through statsd.
  #
  class ServerMiddleware
    ##
    # Initializes the middleware with options.
    #
    # @param [Hash] options The options to initialize the StatsD client.
    # @option options [Statsd] :statsd Existing StatsD client.
    # @option options [String] :prefix ("sidekiq") The prefix to segment the metric key (e.g. prefix.worker_name.success|failure).
    # @option options [String] :sidekiq_stats ("true") Send Sidekiq global stats e.g. total enqueued, processed and failed.
    # @option options [String] :worker_stats ("false") Send Sidekiq worker stats (e.g. prefix.worker_name.success|failure).
    def initialize(options = {})
      @options = { prefix: 'sidekiq', sidekiq_stats: true, worker_stats: false }.merge options

      @statsd = options[:statsd] || raise("A StatsD client must be provided")
    end

    ##
    # Pushes the metrics in a batch.
    #
    # @param worker [Sidekiq::Worker] The worker the job belongs to.
    # @param msg [Hash] The job message.
    # @param queue [String] The current queue.
    def call worker, msg, queue
      @statsd.batch do |b|
        begin
          if @options[:worker_stats]
            # colon causes invalid metric names
            worker_name = worker.class.name.gsub('::', '.')
            b.time prefix(worker_name, 'processing_time') do
              yield
            end
            b.increment prefix(worker_name, 'success')
          else
            yield
          end
        rescue => e
          b.increment prefix(worker_name, 'failure') if @options[:worker_stats]
          raise e
        ensure
          report_global_stats(b) if @options[:sidekiq_stats]
          report_worker_stats(b) if @options[:sidekiq_stats]
          report_queue_stats(b, msg['queue'])
        end
      end
    end

    private

    def report_global_stats(statsd)
      sidekiq_stats = Sidekiq::Stats.new

      # Queue sizes
      statsd.gauge prefix('enqueued'), sidekiq_stats.enqueued
      statsd.gauge prefix('retry_set_size'), sidekiq_stats.retry_size

      # All-time counts
      statsd.gauge prefix('processed'), sidekiq_stats.processed
      statsd.gauge prefix('failed'), sidekiq_stats.failed
    end

    def report_queue_stats(statsd, queue_name)
      sidekiq_queue = Sidekiq::Queue.new(queue_name)
      statsd.gauge prefix('queues', queue_name, 'enqueued'), sidekiq_queue.size
      statsd.gauge prefix('queues', queue_name, 'latency'), sidekiq_queue.latency
    end

    def report_worker_stats(statsd)
      workers = Sidekiq::Workers.new.to_a.map { |_pid, _tid, work| work }
      worker_groups = workers.group_by { |worker| worker['queue'] }

      workers.each do |worker|
        runtime = Time.now.to_i - worker['run_at']
        statsd.gauge prefix('queues', worker['queue'], 'runtime'), runtime
      end if @options[:worker_stats]

      worker_groups.each do |queue_name, workers|
        statsd.gauge prefix('queues', queue_name, 'processing'), workers.size
      end
    end

    ##
    # Converts args passed to it into a metric name with prefix.
    #
    # @param [String] args One or more strings to be converted to a metric name.
    def prefix(*args)
      [@options[:prefix], *args].compact.join('.')
    end
  end # ServerMiddleware
end # Sidekiq
