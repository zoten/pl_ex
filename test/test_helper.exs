Application.put_env(:pl_ex, :client_identifier, "test-client-id")
Application.put_env(:pl_ex, :product, "PlExTest")
Application.put_env(:pl_ex, :version, "0.0.1-test")
Application.put_env(:pl_ex, :platform, :elixir)
Application.put_env(:pl_ex, :device, "test")
Application.put_env(:pl_ex, :device_name, "pl_ex_test")
Application.put_env(:pl_ex, :model, "test")
Application.put_env(:pl_ex, :pms_api_version, "1.1.1")

# Ensure test support modules are compiled
Code.require_file("support/mock_server.ex", __DIR__)
Code.require_file("support/version_matrix.ex", __DIR__)

# Start Finch for HTTP requests in tests
{:ok, _} = Finch.start_link(name: PlExFinch)

ExUnit.start()
