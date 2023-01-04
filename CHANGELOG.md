# 3.0.0
Breaking changes (no backward compatible):

* This version make worker stats optional - default false (worker_stats: false)
* `env` has been removed and only prefix is used - default prefix `sidekiq`

# 2.1.0

* Report stats across all workers (processing, runtime)

# 2.0.1

* Fix stuck global stats (retries, processed, etc.)

# 2.0.0

* BREAKING: drop host/port options
* Add support for custom statsd client

# 1.0.0

* Pin minimum Ruby version to 2.4
* Pin minimum Sidekiq version to 2.7
