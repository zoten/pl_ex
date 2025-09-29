defmodule PlEx.ResourcesTest do
  use ExUnit.Case, async: false

  alias PlEx.Resources

  defmodule FakeHTTP do
    @behaviour PlEx.HTTP

    @impl true
    def request(:get, url, headers, _body, _opts) do
      if String.contains?(url, "/api/v2/resources") do
        # Simulate plex.tv resources response
        body =
          [
            %{
              "name" => "Server A",
              "accessToken" => "pms-token-a",
              "connections" => [
                %{"uri" => "https://relay.example", "local" => false, "relay" => true},
                %{"uri" => "http://local.example:32400", "local" => true, "relay" => false},
                %{"uri" => "https://direct.example:32400", "local" => false, "relay" => false}
              ]
            }
          ]
          |> Jason.encode!()

        {:ok, %{status: 200, headers: [{"content-type", "application/json"}], body: body}}
      else
        {:ok, %{status: 404, headers: headers, body: ""}}
      end
    end
  end

  test "discover returns connections computed from resources list" do
    opts = [
      http_adapter: __MODULE__.FakeHTTP,
      credentials_provider: {PlEx.Auth.LegacyToken, token: "LEGACY"}
    ]

    assert {:ok, conns} = Resources.discover(opts)
    assert length(conns) == 3

    assert Enum.all?(conns, fn c -> is_binary(c.base_url) and is_binary(c.access_token) end)
  end

  test "choose_connection prefers local over https direct over relay" do
    connections = [
      %{
        base_url: "https://relay",
        access_token: "t",
        server: %{
          "connections" => [%{"uri" => "https://relay", "local" => false, "relay" => true}]
        }
      },
      %{
        base_url: "https://direct",
        access_token: "t",
        server: %{
          "connections" => [%{"uri" => "https://direct", "local" => false, "relay" => false}]
        }
      },
      %{
        base_url: "http://local:32400",
        access_token: "t",
        server: %{
          "connections" => [%{"uri" => "http://local:32400", "local" => true, "relay" => false}]
        }
      }
    ]

    assert {:ok, best} = Resources.choose_connection(connections)
    assert best.base_url == "http://local:32400"
  end
end
