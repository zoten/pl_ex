defmodule PlEx.Auth.Crypto do
  @moduledoc """
  Cryptographic utilities for JWT authentication.

  Handles Ed25519 keypair generation, JWK formatting, and JWT signing.
  """

  @doc """
  Generates a new Ed25519 keypair and returns {private_key, public_key, jwk}.
  """
  def generate_ed25519_keypair do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)

    jwk = %{
      "kty" => "OKP",
      "crv" => "Ed25519",
      "x" => Base.url_encode64(public_key, padding: false),
      "use" => "sig",
      "alg" => "EdDSA"
    }

    {private_key, public_key, jwk}
  end

  @doc """
  Signs a JWT payload with Ed25519 private key.
  Returns the complete JWT string.
  """
  def sign_jwt(payload, private_key) when is_map(payload) do
    header = %{
      "typ" => "JWT",
      "alg" => "EdDSA"
    }

    header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
    payload_b64 = Base.url_encode64(Jason.encode!(payload), padding: false)

    message = "#{header_b64}.#{payload_b64}"
    signature = :crypto.sign(:eddsa, :sha256, message, [private_key, :ed25519])
    signature_b64 = Base.url_encode64(signature, padding: false)

    "#{message}.#{signature_b64}"
  end

  @doc """
  Extracts the exp claim from a JWT without verification.
  Returns the expiration timestamp or nil.
  """
  def extract_exp(jwt) when is_binary(jwt) do
    case String.split(jwt, ".") do
      [_header, payload_b64, _signature] ->
        with {:ok, payload_json} <- Base.url_decode64(payload_b64, padding: false),
             {:ok, payload} <- Jason.decode(payload_json) do
          payload["exp"]
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
