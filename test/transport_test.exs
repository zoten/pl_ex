defmodule PlEx.TransportTest do
  use ExUnit.Case, async: false

  alias PlEx.Transport

  defmodule FakeCreds do
    @behaviour PlEx.Auth.Credentials

    @impl true
    def init(_opts), do: {:ok, :ok}

    @impl true
    def plex_token(_opts), do: {:ok, {"PLEX_TV_TOKEN", nil}}

    @impl true
    def refresh_plex_token(_opts), do: {:ok, {"PLEX_TV_TOKEN_REFRESHED", nil}}

    @impl true
    def pms_connection(_opts) do
      {:ok, %{base_url: "https://pms.example", access_token: "PMS_TOKEN", server: %{}}}
    end

    @impl true
    def invalidate(_reason, _opts), do: :ok
  end

  defmodule FakeHTTP do
    @behaviour PlEx.HTTP

    @impl true
    def request(method, url, headers, _body, _opts) do
      # Echo back what we received in JSON for easy assertions
      resp = %{
        method: method,
        url: url,
        headers: Enum.map(headers, fn {k, v} -> [k, v] end)
      }

      {:ok,
       %{status: 200, headers: [{"content-type", "application/json"}], body: Jason.encode!(resp)}}
    end
  end

  setup do
    old_http = Application.get_env(:pl_ex, :http_adapter)
    Application.put_env(:pl_ex, :http_adapter, FakeHTTP)

    on_exit(fn ->
      Application.put_env(:pl_ex, :http_adapter, old_http)
    end)

    :ok
  end

  test "plex.tv request injects X-Plex-* and plex token" do
    {:ok, resp} =
      Transport.request(:plex_tv, :get, "/api/v2/resources", credentials_provider: FakeCreds)

    # method/url
    assert resp["method"] == "get"
    assert String.starts_with?(resp["url"], "https://plex.tv/api/v2/resources")

    headers = resp["headers"]
    # token header present
    assert Enum.any?(headers, fn [k, v] -> k == "X-Plex-Token" and v == "PLEX_TV_TOKEN" end)
    # accept header present
    assert Enum.any?(headers, fn [k, v] -> k == "Accept" and v == "application/json" end)
    # client identifier present
    assert Enum.any?(headers, fn [k, _] -> k == "X-Plex-Client-Identifier" end)
  end

  test "pms request injects PMS token and builds url from base" do
    {:ok, resp} =
      Transport.request(:pms, :get, "/library/sections", credentials_provider: FakeCreds)

    assert resp["method"] == "get"
    assert resp["url"] == "https://pms.example/library/sections"

    headers = resp["headers"]
    assert Enum.any?(headers, fn [k, v] -> k == "X-Plex-Token" and v == "PMS_TOKEN" end)
  end
end
