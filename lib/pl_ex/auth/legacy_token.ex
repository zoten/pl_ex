defmodule PlEx.Auth.LegacyToken do
  @moduledoc """
  Legacy token credentials provider.

  Uses a pre-provisioned long-lived Plex token for plex.tv, and relies on
  `PlEx.Resources` to discover PMS instances and obtain per-server access tokens.

  Configuration (via opts or application env):
  - :token (required) – The legacy Plex token for plex.tv endpoints
  - :storage – module implementing `PlEx.Auth.Storage` (optional)
  - :client_identifier – required header value for Plex requests
  - Other `X-Plex-*` metadata can be passed through opts for future use
  """
  @behaviour PlEx.Auth.Credentials

  alias PlEx.{Error, Config}

  @impl true
  def init(_opts) do
    {:ok, :legacy}
  end

  @impl true
  def plex_token(opts) do
    case Keyword.get(opts, :token) || Config.legacy_token() do
      token when is_binary(token) and byte_size(token) > 0 -> {:ok, {token, nil}}
      _ -> {:error, Error.config_error(:missing_legacy_token)}
    end
  end

  @impl true
  def refresh_plex_token(opts), do: plex_token(opts)

  @impl true
  def pms_connection(opts) do
    with {:ok, {token, _}} <- plex_token(opts),
         {:ok, connections} <-
           PlEx.Resources.discover(
             Keyword.put(opts, :credentials_provider, {__MODULE__, token: token})
           ),
         {:ok, best} <- PlEx.Resources.choose_connection(connections) do
      {:ok, best}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def invalidate(_reason, _opts), do: :ok
end
