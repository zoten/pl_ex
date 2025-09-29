defmodule PlEx.Resources do
  @moduledoc """
  PMS resources discovery and selection (scaffold).

  Responsible for calling plex.tv resources API to enumerate servers and
  selecting the best connection (local > direct > relay) and returning
  `{base_url, access_token, server}`.
  """

  @type connection :: %{
          base_url: String.t(),
          access_token: String.t(),
          server: map()
        }

  # Plex.tv resources API endpoint
  @resources_endpoint "/api/v2/resources"

  # Connection scoring weights (higher is better)
  @score_https 1
  @score_local 2
  @score_relay_penalty -5

  @spec discover(keyword()) :: {:ok, [connection()]} | {:error, term()}
  def discover(opts) do
    params = %{
      includeHttps: 1,
      includeRelay: 1,
      includeIPv6: 1
    }

    path = @resources_endpoint <> "?" <> URI.encode_query(params)

    case PlEx.Transport.request(:plex_tv, :get, path, opts) do
      {:ok, list} when is_list(list) ->
        {:ok, Enum.flat_map(list, &server_to_connections/1)}

      {:ok, %{"MediaContainer" => mc}} ->
        # In case server returns XML converted structure; unlikely here
        {:ok, mc}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec choose_connection([connection()]) :: {:ok, connection()} | {:error, :no_connections}
  def choose_connection(connections) do
    case Enum.sort_by(connections, &score_connection/1, :desc) do
      [best | _] -> {:ok, best}
      _ -> {:error, :no_connections}
    end
  end

  defp server_to_connections(server) do
    access_token = server["accessToken"] || server["access_token"]
    conns = server["connections"] || []

    Enum.flat_map(conns, fn conn ->
      if is_binary(access_token) do
        [%{base_url: conn["uri"], access_token: access_token, server: server}]
      else
        []
      end
    end)
  end

  # Higher is better
  defp score_connection(%{server: server, base_url: url}) do
    connections = server["connections"] || []
    this = Enum.find(connections, &(&1["uri"] == url)) || %{}

    https = if String.starts_with?(url, "https"), do: @score_https, else: 0
    local = if this["local"], do: @score_local, else: 0
    relay = if this["relay"], do: @score_relay_penalty, else: 0

    https + local + relay
  end
end
