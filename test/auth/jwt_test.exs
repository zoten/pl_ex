defmodule PlEx.Auth.JWTTest do
  use ExUnit.Case, async: false

  alias PlEx.Auth.{JWT, Storage.InMemory}

  defmodule FakeHTTP do
    @behaviour PlEx.HTTP

    @impl true
    def request(method, url, _headers, _body, _opts) do
      cond do
        String.contains?(url, "/api/v2/auth/jwk") and method == :post ->
          # JWK registration
          {:ok, %{status: 200, headers: [], body: "{}"}}

        String.contains?(url, "/api/v2/auth/nonce") and method == :get ->
          # Nonce request
          nonce = "test-nonce-#{:rand.uniform(1000)}"
          body = Jason.encode!(%{"nonce" => nonce})
          {:ok, %{status: 200, headers: [{"content-type", "application/json"}], body: body}}

        String.contains?(url, "/api/v2/auth/token") and method == :post ->
          # Token exchange
          # Create a fake JWT with exp claim
          now = System.system_time(:second)
          # 7 days
          exp = now + 7 * 24 * 3600

          fake_jwt_payload = %{"exp" => exp, "sub" => "test-user"}

          fake_jwt =
            "header." <>
              Base.url_encode64(Jason.encode!(fake_jwt_payload), padding: false) <> ".signature"

          body = Jason.encode!(%{"auth_token" => fake_jwt})
          {:ok, %{status: 200, headers: [{"content-type", "application/json"}], body: body}}

        String.contains?(url, "/api/v2/resources") ->
          # Resources for PMS connection
          body =
            Jason.encode!([
              %{
                "name" => "Test Server",
                "accessToken" => "pms-token-123",
                "connections" => [
                  %{"uri" => "https://test.plex:32400", "local" => false, "relay" => false}
                ]
              }
            ])

          {:ok, %{status: 200, headers: [{"content-type", "application/json"}], body: body}}

        true ->
          {:ok, %{status: 404, headers: [], body: "Not Found"}}
      end
    end
  end

  setup do
    # Use in-memory storage for tests
    storage = InMemory
    storage.delete(:device_keypair)
    storage.delete(:plex_token)
    storage.delete(:plex_token_exp)

    opts = [
      storage: storage,
      http_adapter: FakeHTTP
    ]

    {:ok, opts: opts}
  end

  test "init generates and registers device keypair", %{opts: opts} do
    assert {:ok, :jwt} = JWT.init(opts)

    storage = opts[:storage]
    assert {:ok, {_private_key, _jwk}} = storage.get(:device_keypair)
  end

  test "plex_token performs full JWT flow on first call", %{opts: opts} do
    # Initialize first
    {:ok, :jwt} = JWT.init(opts)

    # Get token should trigger nonce -> sign -> exchange
    assert {:ok, {token, exp}} = JWT.plex_token(opts)
    assert is_binary(token)
    assert is_integer(exp)
    assert exp > System.system_time(:second)
  end

  test "plex_token returns cached token when valid", %{opts: opts} do
    {:ok, :jwt} = JWT.init(opts)

    # First call
    {:ok, {token1, exp1}} = JWT.plex_token(opts)

    # Second call should return same cached token
    {:ok, {token2, exp2}} = JWT.plex_token(opts)

    assert token1 == token2
    assert exp1 == exp2
  end

  test "pms_connection uses JWT token for resources discovery", %{opts: opts} do
    {:ok, :jwt} = JWT.init(opts)

    assert {:ok, %{base_url: base_url, access_token: access_token}} = JWT.pms_connection(opts)
    assert base_url == "https://test.plex:32400"
    assert access_token == "pms-token-123"
  end

  test "invalidate clears cached tokens", %{opts: opts} do
    {:ok, :jwt} = JWT.init(opts)
    {:ok, {_token, _exp}} = JWT.plex_token(opts)

    storage = opts[:storage]
    assert {:ok, _} = storage.get(:plex_token)

    JWT.invalidate(:plex_tv_error, opts)

    assert :error = storage.get(:plex_token)
    assert :error = storage.get(:plex_token_exp)
  end
end
