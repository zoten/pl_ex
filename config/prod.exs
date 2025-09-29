import Config

# Production configuration for PlEx
config :pl_ex,
  # Conservative timeouts for production
  request_timeout: 30_000,

  # Reasonable retry policy
  retries: 3,
  backoff_base_ms: 500,

  # Longer cache TTL for production
  cache_ttl: 600,

  # Larger connection pool for production
  connection_pool_size: 20

# Production servers should be configured via runtime.exs or environment variables
# Do not hardcode production credentials here!
