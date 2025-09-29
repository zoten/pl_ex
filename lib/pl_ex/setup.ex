defmodule PlEx.Setup do
  @moduledoc """
  Setup and validation utilities for PlEx in real environments.

  Provides functions to validate configuration, test connections,
  and guide users through initial setup.
  """

  require Logger

  @doc """
  Validates the current PlEx configuration and provides setup guidance.

  ## Examples

      case PlEx.Setup.validate_setup() do
        :ok -> 
          IO.puts("✅ PlEx is ready to use!")
        {:error, issues} -> 
          IO.puts("❌ Configuration issues found:")
          Enum.each(issues, fn issue -> IO.puts("  - " <> issue) end)
      end
  """
  def validate_setup do
    with :ok <- PlEx.Config.validate_config(),
         :ok <- validate_http_client(),
         :ok <- validate_auth_setup() do
      :ok
    else
      {:error, issues} when is_list(issues) -> {:error, issues}
      {:error, issue} -> {:error, [issue]}
    end
  end

  @doc """
  Tests connection to a Plex server.

  ## Examples

      PlEx.Setup.test_connection("http://localhost:32400")
      PlEx.Setup.test_connection("https://my-plex-server.com:32400")
  """
  def test_connection(server_url) do
    Logger.info("Testing connection to #{server_url}...")

    # Store current config
    old_server = PlEx.Config.default_server()

    try do
      # Temporarily set server for testing
      PlEx.Config.set_global_config(default_server: server_url)

      # Try to get server identity (doesn't require auth)
      case PlEx.Transport.request(:pms, :get, "/identity") do
        {:ok, %{"MediaContainer" => %{"machineIdentifier" => machine_id}}} ->
          Logger.info("✅ Successfully connected to Plex server: #{machine_id}")
          {:ok, %{machine_identifier: machine_id, server_url: server_url}}

        {:ok, response} ->
          Logger.warning("⚠️  Got unexpected response: #{inspect(response)}")
          {:error, :unexpected_response}

        {:error, reason} ->
          Logger.error("❌ Connection failed: #{inspect(reason)}")
          {:error, reason}
      end
    after
      # Restore original config
      if old_server do
        PlEx.Config.set_global_config(default_server: old_server)
      end
    end
  end

  @doc """
  Interactive setup wizard for first-time users.
  """
  def interactive_setup do
    IO.puts("""

    🎬 PlEx Setup Wizard
    ===================

    Let's get PlEx configured for your Plex Media Server!
    """)

    # Step 1: Client Identifier
    client_id = get_or_generate_client_id()
    IO.puts("✅ Client ID: #{client_id}")

    # Step 2: Server URL
    server_url = prompt_for_server_url()
    IO.puts("✅ Server URL: #{server_url}")

    # Step 3: Test connection
    IO.puts("\n🔍 Testing connection...")

    case test_connection(server_url) do
      {:ok, info} ->
        IO.puts("✅ Connection successful!")
        IO.puts("   Server ID: #{info.machine_identifier}")

        # Step 4: Generate config
        config = generate_config(client_id, server_url)
        IO.puts("\n📝 Add this to your config/config.exs:")
        IO.puts(config)

        {:ok, %{client_id: client_id, server_url: server_url}}

      {:error, reason} ->
        IO.puts("❌ Connection failed: #{inspect(reason)}")
        IO.puts("Please check your server URL and try again.")
        {:error, reason}
    end
  end

  # Private functions

  defp validate_http_client do
    case PlEx.Config.http_adapter() do
      PlEx.HTTP.FinchAdapter ->
        if Code.ensure_loaded?(Finch) do
          :ok
        else
          {:error, "Finch is not available. Add {:finch, \"~> 0.18\"} to your deps."}
        end

      adapter ->
        if Code.ensure_loaded?(adapter) do
          :ok
        else
          {:error, "HTTP adapter #{adapter} is not available."}
        end
    end
  end

  defp validate_auth_setup do
    case PlEx.Config.auth_provider() do
      PlEx.Auth.JWT ->
        :ok

      provider when is_atom(provider) ->
        if Code.ensure_loaded?(provider) do
          :ok
        else
          {:error, "Auth provider #{provider} is not available."}
        end

      _ ->
        {:error, "Invalid auth provider configuration."}
    end
  end

  defp get_or_generate_client_id do
    case Application.get_env(:pl_ex, :client_identifier) do
      nil ->
        # Generate a reasonable default
        app_name = Application.get_env(:pl_ex, :app_name, "elixir-app")
        version = Application.get_env(:pl_ex, :app_version, "1.0.0")
        "#{app_name}-#{version}"

      existing ->
        existing
    end
  end

  defp prompt_for_server_url do
    default = "http://localhost:32400"

    IO.write("Enter your Plex server URL [#{default}]: ")

    case IO.read(:line) |> String.trim() do
      "" -> default
      url -> url
    end
  end

  defp generate_config(client_id, server_url) do
    """

    config :pl_ex,
      client_identifier: "#{client_id}",
      default_server: "#{server_url}",
      
      # Application metadata
      product: "My Elixir App",
      version: "1.0.0",
      platform: :elixir,
      device: "server",
      device_name: "my-elixir-server",
      
      # HTTP client (make sure to add Finch to your supervision tree)
      http_adapter: PlEx.HTTP.FinchAdapter,
      finch_name: PlExFinch,
      
      # Authentication (JWT is recommended)
      auth_provider: PlEx.Auth.JWT
    """
  end
end
