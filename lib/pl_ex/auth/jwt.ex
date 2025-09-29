defmodule PlEx.Auth.JWT do
  @moduledoc """
  JWT credentials provider.

  This provider:
  - Registers device JWK with plex.tv (if needed)
  - Obtains nonce, signs device JWT (Ed25519), exchanges for plex.tv JWT
  - Caches token with exp and refreshes on 498 or nearing expiry
  - Uses PlEx.Resources for PMS connection discovery
  """
  @behaviour PlEx.Auth.Credentials

  alias PlEx.Auth.Crypto
  alias PlEx.{Transport, Resources, Error, Config}

  # JWT token configuration
  # Refresh when < 1 hour remaining
  @refresh_threshold_seconds 3600
  # 5 minutes for device JWT
  @device_jwt_exp_seconds 300
  @scope "username,email,friendly_name"

  # Plex.tv API endpoints
  @nonce_endpoint "/api/v2/auth/nonce"
  @jwk_endpoint "/api/v2/auth/jwk"
  @token_endpoint "/api/v2/auth/token"

  @impl true
  def init(opts) do
    storage = resolve_storage(opts)

    case ensure_device_keypair(storage, opts) do
      :ok -> {:ok, :jwt}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def plex_token(opts) do
    storage = resolve_storage(opts)

    case get_cached_token(storage) do
      {:ok, token, exp} when is_integer(exp) ->
        if System.system_time(:second) + @refresh_threshold_seconds < exp do
          {:ok, {token, exp}}
        else
          refresh_plex_token(opts)
        end

      {:ok, token, nil} ->
        # Legacy token or no expiry info, assume valid
        {:ok, {token, nil}}

      :error ->
        refresh_plex_token(opts)
    end
  end

  @impl true
  def refresh_plex_token(opts) do
    storage = resolve_storage(opts)

    with {:ok, nonce} <- get_nonce(opts),
         {:ok, device_jwt} <- create_device_jwt(nonce, storage, opts),
         {:ok, plex_jwt, exp} <- exchange_for_plex_token(device_jwt, opts) do
      :ok = storage.put(:plex_token, plex_jwt)
      :ok = storage.put(:plex_token_exp, exp)

      {:ok, {plex_jwt, exp}}
    end
  end

  @impl true
  def pms_connection(opts) do
    with {:ok, {token, _}} <- plex_token(opts),
         {:ok, connections} <-
           Resources.discover(
             Keyword.put(opts, :credentials_provider, {__MODULE__, token: token})
           ) do
      Resources.choose_connection(connections)
    end
  end

  @impl true
  def invalidate(reason, opts) do
    storage = resolve_storage(opts)

    case reason do
      :plex_tv_error ->
        storage.delete(:plex_token)
        storage.delete(:plex_token_exp)

      :pms_error ->
        # Could invalidate cached resources here if we cached them
        :ok

      _ ->
        :ok
    end

    :ok
  end

  # Private functions

  defp resolve_storage(opts) do
    Keyword.get(opts, :storage, Config.storage())
  end

  defp ensure_device_keypair(storage, opts) do
    case storage.get(:device_keypair) do
      {:ok, _keypair} -> :ok
      :error -> generate_and_register_keypair(storage, opts)
    end
  end

  defp generate_and_register_keypair(storage, opts) do
    {private_key, _public_key, jwk} = Crypto.generate_ed25519_keypair()

    case register_jwk(jwk, opts) do
      :ok ->
        storage.put(:device_keypair, {private_key, jwk})
        :ok

      {:error, reason} ->
        {:error, {:jwk_registration_failed, reason}}
    end
  end

  defp register_jwk(jwk, opts) do
    body = Jason.encode!(%{"jwk" => jwk})
    headers = [{"Content-Type", "application/json"}]

    # JWK registration requires an existing token (legacy or previous JWT)
    # For initial setup, this should be called with a legacy token or skipped
    case Keyword.get(opts, :existing_token) do
      token when is_binary(token) ->
        auth_opts =
          Keyword.put(opts, :credentials_provider, {PlEx.Auth.LegacyToken, token: token})

        case Transport.request(
               :plex_tv,
               :post,
               @jwk_endpoint,
               Keyword.merge(auth_opts, body: body, headers: headers)
             ) do
          {:ok, _response} -> :ok
          {:error, reason} -> {:error, reason}
        end

      nil ->
        # Skip JWK registration for now - can be done later with existing token
        :ok
    end
  end

  defp get_cached_token(storage) do
    case {storage.get(:plex_token), storage.get(:plex_token_exp)} do
      {{:ok, token}, {:ok, exp}} -> {:ok, token, exp}
      {{:ok, token}, :error} -> {:ok, token, nil}
      {:error, _} -> :error
    end
  end

  defp get_nonce(opts) do
    # Nonce request doesn't require authentication
    no_auth_opts = Keyword.put(opts, :skip_auth, true)

    case Transport.request(:plex_tv, :get, @nonce_endpoint, no_auth_opts) do
      {:ok, %{"nonce" => nonce}} -> {:ok, nonce}
      {:error, reason} -> {:error, Error.auth_error(:nonce_failed, %{reason: reason})}
    end
  end

  defp create_device_jwt(nonce, storage, _opts) do
    case storage.get(:device_keypair) do
      {:ok, {private_key, _jwk}} ->
        client_id = Config.client_identifier!()
        now = System.system_time(:second)

        payload = %{
          "nonce" => nonce,
          "scope" => @scope,
          "aud" => "plex.tv",
          "iss" => client_id,
          "iat" => now,
          "exp" => now + @device_jwt_exp_seconds
        }

        device_jwt = Crypto.sign_jwt(payload, private_key)
        {:ok, device_jwt}

      :error ->
        {:error, Error.crypto_error(:no_device_keypair)}
    end
  end

  defp exchange_for_plex_token(device_jwt, opts) do
    body = Jason.encode!(%{"jwt" => device_jwt})
    headers = [{"Content-Type", "application/json"}]

    # Token exchange doesn't require existing auth
    no_auth_opts = Keyword.merge(opts, body: body, headers: headers, skip_auth: true)

    case Transport.request(:plex_tv, :post, @token_endpoint, no_auth_opts) do
      {:ok, %{"auth_token" => plex_jwt}} ->
        exp = Crypto.extract_exp(plex_jwt)
        {:ok, plex_jwt, exp}

      {:error, reason} ->
        {:error, Error.auth_error(:token_exchange_failed, %{reason: reason})}
    end
  end
end
