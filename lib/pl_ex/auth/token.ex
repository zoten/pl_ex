defmodule PlEx.Auth.Token do
  @moduledoc """
  Token-based authentication for Plex Media Server.

  This module handles legacy Plex tokens (X-Plex-Token) which are simpler
  than JWT authentication but still widely used.

  ## Token Sources

  Tokens are retrieved from multiple sources in order of preference:
  1. Application configuration `:legacy_token`
  2. Environment variable `PLEX_TOKEN`
  3. Environment variable `PLEX_API_KEY` (alias)

  ## Usage

      # Set via environment variable
      export PLEX_TOKEN="your-plex-token-here"
      
      # Or via application config
      config :pl_ex, legacy_token: "your-plex-token-here"
      
      # Use token authentication
      config :pl_ex, auth_provider: PlEx.Auth.Token

  ## Getting Your Token

  You can get your Plex token from:
  1. Plex Web App: Settings → Account → Privacy → "Show Advanced"
  2. Plex API: POST to /users/sign_in.xml with credentials
  3. Third-party tools like PlexAPI
  """

  @behaviour PlEx.Auth.Credentials

  require Logger

  @doc """
  Retrieves the current Plex token from configuration or environment.

  ## Examples

      iex> PlEx.Auth.Token.get_token()
      {:ok, "abc123def456"}
      
      iex> PlEx.Auth.Token.get_token()
      {:error, :no_token_configured}
  """
  def get_token do
    case PlEx.Config.legacy_token() do
      nil ->
        {:error, :no_token_configured}

      token when is_binary(token) and byte_size(token) > 0 ->
        {:ok, token}

      _ ->
        {:error, :invalid_token_format}
    end
  end

  @doc """
  Sets a token in the application environment (runtime only).

  This is useful for testing or dynamic configuration.

  ## Examples

      PlEx.Auth.Token.set_token("new-token-123")
  """
  def set_token(token) when is_binary(token) do
    Application.put_env(:pl_ex, :legacy_token, token)
    :ok
  end

  @doc """
  Clears the current token from application environment.
  """
  def clear_token do
    Application.delete_env(:pl_ex, :legacy_token)
    :ok
  end

  @doc """
  Validates that a token is properly formatted.

  Plex tokens are typically 20 character alphanumeric strings.
  """
  def valid_token?(token) when is_binary(token) do
    # Basic validation - Plex tokens are usually 20 chars, alphanumeric
    String.match?(token, ~r/^[a-zA-Z0-9]{15,25}$/)
  end

  def valid_token?(_), do: false

  # Credentials behaviour implementation

  @impl PlEx.Auth.Credentials
  def init(_opts) do
    # Token auth doesn't need initialization
    {:ok, :no_state}
  end

  @impl PlEx.Auth.Credentials
  def plex_token(_opts) do
    case get_token() do
      {:ok, token} ->
        # Return token with no expiry (tokens are long-lived)
        {:ok, {token, nil}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl PlEx.Auth.Credentials
  def refresh_plex_token(opts) do
    # Token auth doesn't need refresh - tokens are long-lived
    plex_token(opts)
  end

  @impl PlEx.Auth.Credentials
  def pms_connection(opts) do
    case get_token() do
      {:ok, token} ->
        Logger.debug("Using token authentication for PMS connection")

        # For token auth, we just need to add the token to headers
        server_url = Keyword.get(opts, :server_url) || PlEx.Config.default_server()

        if server_url do
          {:ok,
           %{
             base_url: server_url,
             access_token: token,
             server: %{url: server_url}
           }}
        else
          {:error, :no_server_configured}
        end

      {:error, reason} ->
        Logger.error("Token authentication failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl PlEx.Auth.Credentials
  def invalidate(_reason, _opts) do
    # For token auth, we just clear the local token
    clear_token()
    :ok
  end
end
