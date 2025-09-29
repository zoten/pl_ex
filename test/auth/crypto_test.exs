defmodule PlEx.Auth.CryptoTest do
  use ExUnit.Case, async: true

  alias PlEx.Auth.Crypto

  test "generate_ed25519_keypair returns valid keypair and JWK" do
    {private_key, public_key, jwk} = Crypto.generate_ed25519_keypair()

    assert is_binary(private_key)
    assert is_binary(public_key)
    assert byte_size(private_key) == 32
    assert byte_size(public_key) == 32

    assert jwk["kty"] == "OKP"
    assert jwk["crv"] == "Ed25519"
    assert jwk["use"] == "sig"
    assert jwk["alg"] == "EdDSA"
    assert is_binary(jwk["x"])
  end

  test "sign_jwt creates valid JWT structure" do
    {private_key, _public_key, _jwk} = Crypto.generate_ed25519_keypair()

    payload = %{
      "iss" => "test-client",
      "aud" => "plex.tv",
      "iat" => System.system_time(:second),
      "exp" => System.system_time(:second) + 300
    }

    jwt = Crypto.sign_jwt(payload, private_key)

    # Should have 3 parts separated by dots
    parts = String.split(jwt, ".")
    assert length(parts) == 3

    [header_b64, payload_b64, signature_b64] = parts

    # Header should decode to valid JSON
    {:ok, header_json} = Base.url_decode64(header_b64, padding: false)
    {:ok, header} = Jason.decode(header_json)
    assert header["typ"] == "JWT"
    assert header["alg"] == "EdDSA"

    # Payload should decode to our original payload
    {:ok, payload_json} = Base.url_decode64(payload_b64, padding: false)
    {:ok, decoded_payload} = Jason.decode(payload_json)
    assert decoded_payload["iss"] == "test-client"
    assert decoded_payload["aud"] == "plex.tv"

    # Signature should be base64url encoded
    assert {:ok, _signature} = Base.url_decode64(signature_b64, padding: false)
  end

  test "extract_exp returns expiration from JWT" do
    {private_key, _public_key, _jwk} = Crypto.generate_ed25519_keypair()

    exp_time = System.system_time(:second) + 3600
    payload = %{"exp" => exp_time, "iss" => "test"}

    jwt = Crypto.sign_jwt(payload, private_key)

    assert Crypto.extract_exp(jwt) == exp_time
  end

  test "extract_exp returns nil for invalid JWT" do
    assert Crypto.extract_exp("invalid.jwt") == nil
    assert Crypto.extract_exp("not-a-jwt") == nil
  end
end
