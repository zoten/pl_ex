defmodule PlEx.Test.MockServer do
  @moduledoc """
  Mock server for testing PlEx across different API versions.

  Provides version-specific mock responses and simulates different
  Plex Media Server API behaviors for comprehensive testing.
  """

  use GenServer

  @supported_versions ["1.1.1", "1.2.0", "1.3.0"]
  @default_version "1.1.1"

  # Client API

  @doc """
  Starts the mock server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sets the current API version for mock responses.
  """
  def set_version(version) when version in @supported_versions do
    GenServer.call(__MODULE__, {:set_version, version})
  end

  @doc """
  Resets to the default version.
  """
  def reset_version do
    GenServer.call(__MODULE__, {:set_version, @default_version})
  end

  @doc """
  Gets the current mock server version.
  """
  def get_version do
    GenServer.call(__MODULE__, :get_version)
  end

  @doc """
  Gets a mock connection for the current version.
  """
  def get_connection do
    version = get_version()

    %{
      base_url: "http://localhost:32400",
      access_token: "mock-token-#{version}",
      version: version,
      server: get_mock_server_info(version)
    }
  end

  @doc """
  Checks if mock data exists for a specific version.
  """
  def has_mock_data_for_version?(version) do
    version in @supported_versions
  end

  @doc """
  Registers a custom mock response for testing.
  """
  def register_mock_response(method, path, version, response) do
    GenServer.call(__MODULE__, {:register_mock, method, path, version, response})
  end

  @doc """
  Clears all custom mock responses.
  """
  def clear_mock_responses do
    GenServer.call(__MODULE__, :clear_mocks)
  end

  @doc """
  Simulates a request to the mock server.
  """
  def request(method, url, headers, body, opts) do
    GenServer.call(__MODULE__, {:request, method, url, headers, body, opts})
  end

  # GenServer implementation

  @impl true
  def init(_opts) do
    state = %{
      current_version: @default_version,
      custom_mocks: %{},
      request_log: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:set_version, version}, _from, state) do
    {:reply, :ok, %{state | current_version: version}}
  end

  @impl true
  def handle_call(:get_version, _from, state) do
    {:reply, state.current_version, state}
  end

  @impl true
  def handle_call({:register_mock, method, path, version, response}, _from, state) do
    key = {method, path, version}
    custom_mocks = Map.put(state.custom_mocks, key, response)
    {:reply, :ok, %{state | custom_mocks: custom_mocks}}
  end

  @impl true
  def handle_call(:clear_mocks, _from, state) do
    {:reply, :ok, %{state | custom_mocks: %{}, request_log: []}}
  end

  @impl true
  def handle_call({:request, method, url, headers, body, opts}, _from, state) do
    # Log the request
    request_entry = %{
      method: method,
      url: url,
      headers: headers,
      body: body,
      opts: opts,
      timestamp: DateTime.utc_now(),
      version: state.current_version
    }

    request_log = [request_entry | state.request_log]

    # Generate response
    path = extract_path_from_url(url)
    response = generate_mock_response(method, path, state.current_version, state.custom_mocks)

    {:reply, response, %{state | request_log: request_log}}
  end

  # Private functions

  defp extract_path_from_url(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) -> path
      _ -> "/"
    end
  end

  defp generate_mock_response(method, path, version, custom_mocks) do
    # Check for custom mock first
    case Map.get(custom_mocks, {method, path, version}) do
      nil -> generate_default_response(method, path, version)
      custom_response -> custom_response
    end
  end

  defp generate_default_response(method, path, version) do
    case {method, path} do
      {:get, "/"} ->
        {:ok,
         %{
           status: 200,
           headers: [
             {"Content-Type", "application/json"},
             {"X-Plex-Pms-Api-Version", version}
           ],
           body: get_root_response(version)
         }}

      {:get, "/identity"} ->
        {:ok,
         %{
           status: 200,
           headers: [{"Content-Type", "application/json"}],
           body: get_identity_response(version)
         }}

      {:get, "/library/sections"} ->
        {:ok,
         %{
           status: 200,
           headers: [{"Content-Type", "application/json"}],
           body: get_library_sections_response(version)
         }}

      {:get, "/hubs"} ->
        if version_supports_hubs?(version) do
          {:ok,
           %{
             status: 200,
             headers: [{"Content-Type", "application/json"}],
             body: get_hubs_response(version)
           }}
        else
          {:ok,
           %{
             status: 404,
             headers: [{"Content-Type", "application/json"}],
             body: %{"error" => "Not found"}
           }}
        end

      {:get, "/library/collections"} ->
        if version_supports_collections?(version) do
          {:ok,
           %{
             status: 200,
             headers: [{"Content-Type", "application/json"}],
             body: get_collections_response(version)
           }}
        else
          {:ok,
           %{
             status: 404,
             headers: [{"Content-Type", "application/json"}],
             body: %{"error" => "Collections not supported"}
           }}
        end

      _ ->
        {:ok,
         %{
           status: 404,
           headers: [{"Content-Type", "application/json"}],
           body: %{"error" => "Not found"}
         }}
    end
  end

  defp get_root_response(version) do
    base_response = %{
      "MediaContainer" => %{
        "size" => 0,
        "version" => version,
        "machineIdentifier" => "mock-server-#{version}",
        "friendlyName" => "Mock Plex Server"
      }
    }

    case version do
      v when v >= "1.2.0" ->
        put_in(base_response, ["MediaContainer", "features"], ["collections", "hubs"])

      _ ->
        base_response
    end
  end

  defp get_identity_response(version) do
    %{
      "MediaContainer" => %{
        "size" => 1,
        "version" => version,
        "machineIdentifier" => "mock-server-#{version}",
        "claimed" => true,
        "Device" => [
          %{
            "name" => "Mock Plex Server",
            "version" => version,
            "platform" => "Linux",
            "platformVersion" => "Ubuntu 20.04"
          }
        ]
      }
    }
  end

  defp get_library_sections_response(version) do
    base_sections = [
      %{
        "key" => "1",
        "title" => "Movies",
        "type" => "movie",
        "agent" => "com.plexapp.agents.imdb",
        "scanner" => "Plex Movie Scanner",
        "language" => "en",
        "uuid" => "mock-uuid-movies"
      },
      %{
        "key" => "2",
        "title" => "TV Shows",
        "type" => "show",
        "agent" => "com.plexapp.agents.thetvdb",
        "scanner" => "Plex Series Scanner",
        "language" => "en",
        "uuid" => "mock-uuid-shows"
      }
    ]

    # Add version-specific fields
    sections =
      case version do
        v when v >= "1.2.0" ->
          Enum.map(base_sections, fn section ->
            section
            |> Map.put("collectionCount", 5)
            |> Map.put("hubIdentifier", "library.section.#{section["key"]}")
          end)

        _ ->
          base_sections
      end

    %{
      "MediaContainer" => %{
        "size" => length(sections),
        "Directory" => sections
      }
    }
  end

  defp get_hubs_response(version) do
    hubs = [
      %{
        "key" => "/hubs/home/recentlyAdded",
        "title" => "Recently Added",
        "type" => "mixed",
        "hubIdentifier" => "home.recentlyAdded",
        "size" => 20
      },
      %{
        "key" => "/hubs/home/onDeck",
        "title" => "On Deck",
        "type" => "mixed",
        "hubIdentifier" => "home.onDeck",
        "size" => 10
      }
    ]

    # Add version-specific hubs
    enhanced_hubs =
      case version do
        v when v >= "1.3.0" ->
          hubs ++
            [
              %{
                "key" => "/hubs/home/recommendations",
                "title" => "Recommended",
                "type" => "mixed",
                "hubIdentifier" => "home.recommendations",
                "size" => 15
              }
            ]

        _ ->
          hubs
      end

    %{
      "MediaContainer" => %{
        "size" => length(enhanced_hubs),
        "Hub" => enhanced_hubs
      }
    }
  end

  defp get_collections_response(version) do
    collections = [
      %{
        "ratingKey" => "12345",
        "key" => "/library/collections/12345",
        "title" => "Marvel Movies",
        "type" => "collection",
        "childCount" => 25,
        "addedAt" => 1_640_995_200
      },
      %{
        "ratingKey" => "12346",
        "key" => "/library/collections/12346",
        "title" => "Star Wars Saga",
        "type" => "collection",
        "childCount" => 12,
        "addedAt" => 1_640_995_200
      }
    ]

    # Add version-specific fields
    enhanced_collections =
      case version do
        v when v >= "1.3.0" ->
          Enum.map(collections, fn collection ->
            collection
            |> Map.put("smart", false)
            |> Map.put("collectionMode", "default")
          end)

        _ ->
          collections
      end

    %{
      "MediaContainer" => %{
        "size" => length(enhanced_collections),
        "Metadata" => enhanced_collections
      }
    }
  end

  defp get_mock_server_info(version) do
    %{
      "name" => "Mock Plex Server",
      "version" => version,
      "machineIdentifier" => "mock-server-#{version}",
      "platform" => "Linux",
      "platformVersion" => "Ubuntu 20.04",
      "connections" => [
        %{
          "protocol" => "http",
          "address" => "localhost",
          "port" => 32_400,
          "uri" => "http://localhost:32400",
          "local" => true
        }
      ]
    }
  end

  defp version_supports_hubs?(version) do
    PlEx.Version.Compatibility.supports_version?(version, :hubs)
  end

  defp version_supports_collections?(version) do
    PlEx.Version.Compatibility.supports_version?(version, :collections)
  end
end
