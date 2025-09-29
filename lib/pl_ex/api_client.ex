defmodule PlEx.APIClient do
  @moduledoc """
  High-level API client for PlEx with built-in authentication management.

  This module provides convenient functions for setting up and managing
  PlEx authentication, especially useful for environment variable based
  configuration.

  ## Quick Setup

      # Using environment variables
      export PLEX_TOKEN="your-token-here"
      export PLEX_SERVER_URL="http://localhost:32400"
      export PLEX_CLIENT_ID="my-app-v1.0"
      
      # Test connection
      PlEx.APIClient.test_connection()
      
      # Start using PlEx
      {:ok, sections} = PlEx.APIClient.get_library_sections()

  ## Configuration Methods

  ### 1. Environment Variables (Recommended for production)
  ```bash
  export PLEX_TOKEN="abc123def456"
  export PLEX_SERVER_URL="http://localhost:32400"
  export PLEX_CLIENT_ID="my-app-v1.0"
  ```

  ### 2. Application Configuration
  ```elixir
  config :pl_ex,
    legacy_token: "abc123def456",
    default_server: "http://localhost:32400",
    client_identifier: "my-app-v1.0"
  ```

  ### 3. Runtime Configuration
  ```elixir
  PlEx.APIClient.configure(
    token: "abc123def456",
    server: "http://localhost:32400",
    client_id: "my-app-v1.0"
  )
  ```
  """

  use PlEx

  require Logger

  @doc """
  Configures PlEx with the provided options at runtime.

  ## Options

  - `:token` - Plex authentication token
  - `:server` - Plex server URL
  - `:client_id` - Unique client identifier
  - `:auth_method` - Authentication method (`:token` or `:jwt`)

  ## Examples

      PlEx.APIClient.configure(
        token: "abc123def456",
        server: "http://localhost:32400",
        client_id: "my-app-v1.0"
      )
  """
  def configure(opts \\ []) do
    if token = opts[:token] do
      Application.put_env(:pl_ex, :legacy_token, token)
      Application.put_env(:pl_ex, :auth_provider, PlEx.Auth.Token)
    end

    if server = opts[:server] do
      Application.put_env(:pl_ex, :default_server, server)
    end

    if client_id = opts[:client_id] do
      Application.put_env(:pl_ex, :client_identifier, client_id)
    end

    if auth_method = opts[:auth_method] do
      auth_provider =
        case auth_method do
          :token -> PlEx.Auth.Token
          :jwt -> PlEx.Auth.JWT
          provider when is_atom(provider) -> provider
        end

      Application.put_env(:pl_ex, :auth_provider, auth_provider)
    end

    :ok
  end

  @doc """
  Returns the current configuration status.

  ## Examples

      iex> PlEx.APIClient.status()
      %{
        token: :configured,
        server: "http://localhost:32400",
        client_id: "my-app-v1.0",
        auth_method: :token,
        ready: true
      }
  """
  def status do
    %{
      token: if(PlEx.Config.legacy_token(), do: :configured, else: :missing),
      server: PlEx.Config.default_server(),
      client_id: PlEx.Config.client_identifier(),
      auth_method: PlEx.Config.auth_method(),
      auth_provider: PlEx.Config.auth_provider(),
      ready: ready?()
    }
  end

  @doc """
  Checks if PlEx is properly configured and ready to use.

  ## Examples

      iex> PlEx.APIClient.ready?()
      true
      
      iex> PlEx.APIClient.ready?()
      false
  """
  def ready? do
    PlEx.Config.client_identifier() != nil and
      PlEx.Config.default_server() != nil and
      (PlEx.Config.legacy_token() != nil or PlEx.Config.auth_provider() == PlEx.Auth.JWT)
  end

  @doc """
  Tests the connection to the configured Plex server.

  ## Examples

      iex> PlEx.APIClient.test_connection()
      {:ok, %{server: "http://localhost:32400", machine_id: "abc123"}}
      
      iex> PlEx.APIClient.test_connection()
      {:error, :connection_failed}
  """
  def test_connection do
    case ready?() do
      false ->
        {:error, :not_configured}

      true ->
        case get_server_identity() do
          {:ok, identity} ->
            {:ok,
             %{
               server: PlEx.Config.default_server(),
               machine_id: identity["machineIdentifier"],
               version: identity["version"],
               platform: identity["platform"]
             }}

          error ->
            error
        end
    end
  end

  @doc """
  Interactive configuration wizard.

  Prompts for required configuration values if they're not set.
  """
  def setup_wizard do
    IO.puts("""

    🎬 PlEx API Client Setup
    ========================

    Let's configure your Plex connection!
    """)

    # Check current status
    current_status = status()

    # Get token
    token = get_or_prompt_token(current_status.token)

    # Get server URL
    server = get_or_prompt_server(current_status.server)

    # Get client ID
    client_id = get_or_prompt_client_id(current_status.client_id)

    # Configure
    configure(
      token: token,
      server: server,
      client_id: client_id,
      auth_method: :token
    )

    IO.puts("\n🔍 Testing connection...")

    case test_connection() do
      {:ok, info} ->
        IO.puts("✅ Connection successful!")
        IO.puts("   Server: #{info.server}")
        IO.puts("   Machine ID: #{info.machine_id}")
        IO.puts("   Version: #{info.version}")

        IO.puts("""

        🎉 Setup complete! You can now use PlEx:

            {:ok, sections} = PlEx.APIClient.get_library_sections()
            {:ok, results} = PlEx.APIClient.search("batman")
        """)

        {:ok, info}

      {:error, reason} ->
        IO.puts("❌ Connection failed: #{inspect(reason)}")
        IO.puts("Please check your configuration and try again.")
        {:error, reason}
    end
  end

  # Private helper functions

  defp get_or_prompt_token(:configured) do
    PlEx.Config.legacy_token()
  end

  defp get_or_prompt_token(:missing) do
    IO.puts("""

    📝 Plex Token Required

    You need a Plex authentication token. You can get one from:
    1. Plex Web App → Settings → Account → Privacy → "Show Advanced"
    2. Or visit: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
    """)

    IO.write("Enter your Plex token: ")
    IO.read(:line) |> String.trim()
  end

  defp get_or_prompt_server(nil) do
    IO.write("\nEnter your Plex server URL [http://localhost:32400]: ")

    case IO.read(:line) |> String.trim() do
      "" -> "http://localhost:32400"
      url -> url
    end
  end

  defp get_or_prompt_server(existing), do: existing

  defp get_or_prompt_client_id(nil) do
    default = "elixir-plex-client-#{System.system_time(:second)}"
    IO.write("\nEnter client identifier [#{default}]: ")

    case IO.read(:line) |> String.trim() do
      "" -> default
      id -> id
    end
  end

  defp get_or_prompt_client_id(existing), do: existing

  defp get_server_identity do
    # Try to get server identity (doesn't require full auth)
    case PlEx.Transport.request(:pms, :get, "/identity") do
      {:ok, %{"MediaContainer" => identity}} -> {:ok, identity}
      {:ok, identity} when is_map(identity) -> {:ok, identity}
      error -> error
    end
  end
end
