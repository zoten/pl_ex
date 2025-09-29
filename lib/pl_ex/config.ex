defmodule PlEx.Config do
  @moduledoc """
  Central configuration access for PlEx.

  Provides a unified interface for accessing PlEx configuration with sensible defaults
  and runtime configuration support.

  ## Configuration Options

  ### Required
  - `:client_identifier` - Unique identifier for your application

  ### Authentication
  - `:auth_method` - Authentication method (`:jwt`, `:token`, `:pin`)
  - `:auth_provider` - Authentication provider module
  - `:legacy_token` - Plex token for legacy authentication

  ### Connection
  - `:default_server` - Default Plex server URL
  - `:connection_pool_size` - HTTP connection pool size
  - `:request_timeout` - Request timeout in milliseconds

  ### Performance
  - `:cache_ttl` - Cache TTL in seconds
  - `:retries` - Number of retry attempts
  - `:backoff_base_ms` - Base backoff time for retries

  ### HTTP
  - `:http_adapter` - HTTP client adapter
  - `:finch_name` - Finch process name

  ## Examples

      config :pl_ex,
        client_identifier: "my-app-v1.0",
        default_server: "http://localhost:32400",
        auth_method: :jwt,
        cache_ttl: 300,
        connection_pool_size: 10
  """

  # Default configuration values
  @default_product "PlEx"
  @default_version "0.1.0"
  @default_platform :elixir
  @default_device "server"
  @default_device_name "pl_ex"
  @default_model "generic"
  @default_pms_api_version "1.1.1"
  @default_finch_name PlExFinch
  @default_cache_ttl 300
  @default_connection_pool_size 10
  @default_request_timeout 30_000

  @doc """
  Returns the configured HTTP adapter module. Defaults to `PlEx.HTTP.FinchAdapter`.
  """
  def http_adapter do
    Application.get_env(:pl_ex, :http_adapter, PlEx.HTTP.FinchAdapter)
  end

  @doc """
  Returns the configured auth provider module (or {module, opts}). Defaults to `PlEx.Auth.JWT`.
  """
  def auth_provider do
    Application.get_env(:pl_ex, :auth_provider, PlEx.Auth.JWT)
  end

  @doc """
  Returns the Finch name to use.
  """
  def finch_name do
    Application.get_env(:pl_ex, :finch_name, @default_finch_name)
  end

  @doc """
  Returns the X-Plex-* common headers based on configuration.

  Headers are cached after first build for performance.
  """
  def plex_headers do
    case :persistent_term.get({__MODULE__, :cached_headers}, nil) do
      nil ->
        headers = build_plex_headers()
        :persistent_term.put({__MODULE__, :cached_headers}, headers)
        headers

      cached_headers ->
        cached_headers
    end
  end

  @doc """
  Clears the cached headers. Call this if configuration changes at runtime.
  """
  def clear_header_cache do
    :persistent_term.erase({__MODULE__, :cached_headers})
    :ok
  end

  defp build_plex_headers do
    [
      {"X-Plex-Client-Identifier", client_identifier!()},
      {"X-Plex-Product", to_string(Application.get_env(:pl_ex, :product, @default_product))},
      {"X-Plex-Version", to_string(Application.get_env(:pl_ex, :version, @default_version))},
      {"X-Plex-Platform", to_string(Application.get_env(:pl_ex, :platform, @default_platform))},
      {"X-Plex-Device", to_string(Application.get_env(:pl_ex, :device, @default_device))},
      {"X-Plex-Device-Name",
       to_string(Application.get_env(:pl_ex, :device_name, @default_device_name))},
      {"X-Plex-Model", to_string(Application.get_env(:pl_ex, :model, @default_model))},
      {"X-Plex-Pms-Api-Version",
       to_string(Application.get_env(:pl_ex, :pms_api_version, @default_pms_api_version))}
    ]
  end

  def client_identifier! do
    case Application.get_env(:pl_ex, :client_identifier) do
      nil -> raise ArgumentError, ":pl_ex :client_identifier is required"
      id -> id
    end
  end

  @doc """
  Returns retry configuration.
  """
  def retries, do: Application.get_env(:pl_ex, :retries, 3)
  def backoff_base_ms, do: Application.get_env(:pl_ex, :backoff_base_ms, 200)

  @doc """
  Returns storage configuration.
  """
  def storage, do: Application.get_env(:pl_ex, :storage, PlEx.Auth.Storage.InMemory)

  @doc """
  Returns legacy token configuration.

  Supports multiple sources in order of preference:
  1. Application config `:legacy_token`
  2. Environment variable `PLEX_TOKEN`
  3. Environment variable `PLEX_API_KEY` (alias)
  """
  def legacy_token do
    Application.get_env(:pl_ex, :legacy_token) ||
      System.get_env("PLEX_TOKEN") ||
      System.get_env("PLEX_API_KEY")
  end

  # New API-focused configuration functions

  @doc """
  Returns the default server URL.

  Supports multiple sources in order of preference:
  1. Application config `:default_server`
  2. Environment variable `PLEX_SERVER_URL`
  3. Environment variable `PLEX_URL` (alias)
  """
  def default_server do
    Application.get_env(:pl_ex, :default_server) ||
      System.get_env("PLEX_SERVER_URL") ||
      System.get_env("PLEX_URL")
  end

  @doc """
  Returns the client identifier.

  Supports multiple sources in order of preference:
  1. Application config `:client_identifier`
  2. Environment variable `PLEX_CLIENT_ID`
  3. Environment variable `PLEX_CLIENT_IDENTIFIER` (full name)
  """
  def client_identifier do
    Application.get_env(:pl_ex, :client_identifier) ||
      System.get_env("PLEX_CLIENT_ID") ||
      System.get_env("PLEX_CLIENT_IDENTIFIER")
  end

  @doc """
  Returns the authentication method (:jwt, :token, :pin).
  """
  def auth_method, do: Application.get_env(:pl_ex, :auth_method, :jwt)

  @doc """
  Returns the cache TTL in seconds.
  """
  def cache_ttl, do: Application.get_env(:pl_ex, :cache_ttl, @default_cache_ttl)

  @doc """
  Returns the connection pool size.
  """
  def connection_pool_size,
    do: Application.get_env(:pl_ex, :connection_pool_size, @default_connection_pool_size)

  @doc """
  Returns the request timeout in milliseconds.
  """
  def request_timeout, do: Application.get_env(:pl_ex, :request_timeout, @default_request_timeout)

  @doc """
  Sets global configuration at runtime.

  ## Examples

      PlEx.Config.set_global_config([
        default_server: "http://192.168.1.100:32400",
        auth_method: :token,
        cache_ttl: 600
      ])
  """
  def set_global_config(opts) when is_list(opts) do
    Enum.each(opts, fn {key, value} ->
      Application.put_env(:pl_ex, key, value)
    end)

    :ok
  end

  @doc """
  Gets the current global configuration.
  """
  def get_global_config do
    Application.get_all_env(:pl_ex)
  end

  @doc """
  Validates the current configuration and returns any issues.

  ## Examples

      case PlEx.Config.validate_config() do
        :ok -> 
          IO.puts("Configuration is valid")
        {:error, issues} -> 
          IO.puts("Configuration issues: \#{inspect(issues)}")
      end
  """
  def validate_config do
    issues = []

    issues =
      case Application.get_env(:pl_ex, :client_identifier) do
        nil -> ["client_identifier is required" | issues]
        id when is_binary(id) and byte_size(id) > 0 -> issues
        _ -> ["client_identifier must be a non-empty string" | issues]
      end

    issues =
      case auth_method() do
        method when method in [:jwt, :token, :pin] -> issues
        _ -> ["auth_method must be :jwt, :token, or :pin" | issues]
      end

    issues =
      case cache_ttl() do
        ttl when is_integer(ttl) and ttl > 0 -> issues
        _ -> ["cache_ttl must be a positive integer" | issues]
      end

    issues =
      case connection_pool_size() do
        size when is_integer(size) and size > 0 -> issues
        _ -> ["connection_pool_size must be a positive integer" | issues]
      end

    case issues do
      [] -> :ok
      _ -> {:error, Enum.reverse(issues)}
    end
  end

  @doc """
  Returns a complete configuration summary for debugging.
  """
  def debug_config do
    %{
      # Required
      client_identifier: Application.get_env(:pl_ex, :client_identifier),

      # Authentication
      auth_method: auth_method(),
      auth_provider: auth_provider(),
      legacy_token: if(legacy_token(), do: "[REDACTED]", else: nil),

      # Connection
      default_server: default_server(),
      connection_pool_size: connection_pool_size(),
      request_timeout: request_timeout(),

      # Performance
      cache_ttl: cache_ttl(),
      retries: retries(),
      backoff_base_ms: backoff_base_ms(),

      # HTTP
      http_adapter: http_adapter(),
      finch_name: finch_name(),

      # Storage
      storage: storage(),

      # Headers
      product: Application.get_env(:pl_ex, :product, @default_product),
      version: Application.get_env(:pl_ex, :version, @default_version),
      platform: Application.get_env(:pl_ex, :platform, @default_platform),
      device: Application.get_env(:pl_ex, :device, @default_device),
      device_name: Application.get_env(:pl_ex, :device_name, @default_device_name),
      model: Application.get_env(:pl_ex, :model, @default_model),
      pms_api_version: Application.get_env(:pl_ex, :pms_api_version, @default_pms_api_version)
    }
  end
end
