# PlEx Default Configuration
# This file provides sensible defaults for PlEx.
# Override these in your application's config files.

import Config

config :pl_ex,
  # Default HTTP adapter (requires Finch to be started)
  http_adapter: PlEx.HTTP.FinchAdapter,
  finch_name: PlExFinch,

  # Default authentication method
  auth_provider: PlEx.Auth.JWT,

  # Performance defaults
  retries: 3,
  backoff_base_ms: 200,
  cache_ttl: 300,
  connection_pool_size: 10,
  request_timeout: 30_000,

  # Plex client defaults (override these!)
  product: "PlEx",
  version: "0.1.0",
  platform: :elixir,
  device: "server",
  device_name: "pl_ex",
  model: "generic",
  pms_api_version: "1.1.1"

# Import environment-specific config
import_config "#{config_env()}.exs"
