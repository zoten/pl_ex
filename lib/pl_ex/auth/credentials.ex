defmodule PlEx.Auth.Credentials do
  @moduledoc """
  Behaviour for PlEx authentication providers.

  A credentials provider is responsible for:
  - Obtaining and refreshing a plex.tv token (JWT or legacy)
  - Discovering PMS servers and returning a connection (base_url + access_token)
  - Invalidating cached credentials/connections on demand
  """

  @type token :: String.t()
  @type timestamp :: non_neg_integer()
  @type plex_token :: {token(), timestamp() | nil}
  @type connection :: %{
          base_url: String.t(),
          access_token: String.t(),
          server: map()
        }

  @callback init(opts :: keyword()) :: {:ok, any()} | {:error, term()}
  @callback plex_token(opts :: keyword()) :: {:ok, plex_token()} | {:error, term()}
  @callback refresh_plex_token(opts :: keyword()) :: {:ok, plex_token()} | {:error, term()}
  @callback pms_connection(opts :: keyword()) :: {:ok, connection()} | {:error, term()}
  @callback invalidate(reason :: term(), opts :: keyword()) :: :ok
end
