import Config

# Test configuration for PlEx
config :pl_ex,
  # Use Finch for testing (with mock responses in tests)
  http_adapter: PlEx.HTTP.FinchAdapter,

  # Fast timeouts for tests
  request_timeout: 1_000,

  # No retries in tests (fail fast)
  retries: 0,

  # Short cache TTL for tests
  cache_ttl: 1,

  # Test client configuration
  client_identifier: "test-client-id",
  product: "PlExTest",
  version: "0.0.1-test",
  device: "test",
  device_name: "pl_ex_test",
  model: "test"
