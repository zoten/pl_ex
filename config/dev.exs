import Config

# Development configuration for PlEx
config :pl_ex,
  # Enable debug logging
  log_level: :debug,

  # Shorter timeouts for development
  request_timeout: 10_000,

  # More aggressive retries for flaky dev environments
  retries: 5,
  backoff_base_ms: 100

# Example development server (update with your local Plex server)
# config :pl_ex,
#   client_identifier: "my-dev-app-v1.0",
#   default_server: "http://localhost:32400"
