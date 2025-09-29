defmodule PlEx.API.Search do
  @moduledoc """
  Search functionality API for Plex Media Server.

  Provides search capabilities across libraries with version-aware adaptations.
  Handles both basic search (v1.1.1+) and enhanced search with hubs (v1.2.0+).
  """

  import PlEx.API.Base
  alias PlEx.Schemas.Search

  @doc """
  Performs a search across all libraries or a specific library section.

  ## Version Compatibility
  - v1.1.1+: Basic search functionality
  - v1.2.0+: Enhanced search with better filtering and hubs integration

  ## Options

  - `:section_id` - Limit search to specific library section
  - `:type` - Filter by media type (`:movie`, `:show`, `:episode`, etc.)
  - `:limit` - Maximum number of results
  - `:include_collections` - Include collections in results (v1.2.0+)

  ## Examples

      {:ok, results} = PlEx.API.Search.search("avengers")
      {:ok, movies} = PlEx.API.Search.search("batman", type: :movie, section_id: "1")
      {:ok, results} = PlEx.API.Search.search("comedy", include_collections: true)
  """
  @spec search(String.t(), keyword()) :: {:ok, [Search.Result.t()]} | {:error, term()}
  def search(query, opts \\ []) when is_binary(query) and byte_size(query) > 0 do
    with :ok <- require_feature(:basic_search, opts) do
      {:ok, path, params} = get_search_endpoint_and_params(query, opts)
      request_opts = Keyword.put(opts, :params, params)
      request_with_schema(:pms, :get, path, Search.Result, request_opts)
    end
  end

  @doc """
  Performs an advanced search with multiple filters.

  Only available in v1.2.0+ when enhanced search is supported.

  ## Filter Options

  - `:title` - Title contains text
  - `:year` - Release year or year range
  - `:genre` - Genre filter
  - `:director` - Director name
  - `:actor` - Actor name
  - `:studio` - Studio/network name
  - `:content_rating` - Content rating (PG, R, etc.)
  - `:resolution` - Video resolution
  - `:added_after` - Added after date
  - `:added_before` - Added before date

  ## Examples

      {:ok, results} = PlEx.API.Search.advanced_search(%{
        genre: "Action",
        year: {2020, 2023},
        resolution: "4k"
      })

      {:ok, results} = PlEx.API.Search.advanced_search(%{
        actor: "Tom Hanks",
        added_after: ~D[2023-01-01]
      }, section_id: "1")
  """
  @spec advanced_search(map(), keyword()) :: {:ok, [Search.Result.t()]} | {:error, term()}
  def advanced_search(filters, opts \\ []) when is_map(filters) do
    with :ok <- require_feature(:enhanced_search, opts) do
      path = "/hubs/search"
      params = build_advanced_search_params(filters, opts)
      request_opts = Keyword.put(opts, :params, params)

      request_with_schema(:pms, :get, path, Search.Result, request_opts)
    end
  end

  @doc """
  Gets search suggestions based on partial input.

  Only available in v1.2.0+ with enhanced search.

  ## Examples

      {:ok, suggestions} = PlEx.API.Search.get_suggestions("aven")
      # => ["Avengers", "Avengers: Endgame", "Avenue Q"]
  """
  @spec get_suggestions(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def get_suggestions(partial_query, opts \\ []) when is_binary(partial_query) do
    with :ok <- require_feature(:enhanced_search, opts) do
      path = "/hubs/search/suggestions"
      params = %{"query" => partial_query}
      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :get, path, request_opts) do
        {:ok, %{"MediaContainer" => %{"Hub" => hubs}}} when is_list(hubs) ->
          suggestions = extract_suggestions_from_hubs(hubs)
          {:ok, suggestions}

        {:ok, %{"MediaContainer" => %{"Hub" => hub}}} when is_map(hub) ->
          suggestions = extract_suggestions_from_hubs([hub])
          {:ok, suggestions}

        {:ok, _response} ->
          {:ok, []}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Searches within a specific media item (e.g., episodes within a show).

  ## Examples

      {:ok, episodes} = PlEx.API.Search.search_within("12345", "pilot")
      {:ok, tracks} = PlEx.API.Search.search_within("67890", "love song")
  """
  @spec search_within(String.t(), String.t(), keyword()) ::
          {:ok, [Search.Result.t()]} | {:error, term()}
  def search_within(parent_rating_key, query, opts \\ [])
      when is_binary(parent_rating_key) and is_binary(query) do
    with :ok <- require_feature(:basic_search, opts) do
      path = "/library/metadata/#{parent_rating_key}/children"
      params = build_search_within_params(query, opts)
      request_opts = Keyword.put(opts, :params, params)

      request_with_schema(:pms, :get, path, Search.Result, request_opts)
    end
  end

  @doc """
  Gets popular or trending search terms.

  Only available in v1.3.0+ with activity monitoring.

  ## Examples

      {:ok, trending} = PlEx.API.Search.get_trending_searches()
      {:ok, popular} = PlEx.API.Search.get_trending_searches(period: :week)
  """
  @spec get_trending_searches(keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def get_trending_searches(opts \\ []) do
    with :ok <- require_feature(:activity_monitoring, opts) do
      path = "/hubs/search/trending"
      params = build_trending_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :get, path, request_opts) do
        {:ok, %{"MediaContainer" => %{"Hub" => hubs}}} when is_list(hubs) ->
          terms = extract_trending_terms(hubs)
          {:ok, terms}

        {:ok, %{"MediaContainer" => %{"Hub" => hub}}} when is_map(hub) ->
          terms = extract_trending_terms([hub])
          {:ok, terms}

        {:ok, _response} ->
          {:ok, []}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Searches for people (actors, directors, writers).

  ## Examples

      {:ok, people} = PlEx.API.Search.search_people("Tom Hanks")
      {:ok, directors} = PlEx.API.Search.search_people("Spielberg", role: :director)
  """
  @spec search_people(String.t(), keyword()) :: {:ok, [Search.Person.t()]} | {:error, term()}
  def search_people(query, opts \\ []) when is_binary(query) do
    with :ok <- require_feature(:basic_search, opts) do
      path = "/search"
      params = build_people_search_params(query, opts)
      request_opts = Keyword.put(opts, :params, params)

      request_with_schema(:pms, :get, path, Search.Person, request_opts)
    end
  end

  @doc """
  Gets search history for the current user.

  Only available in v1.3.0+ with activity monitoring.

  ## Examples

      {:ok, history} = PlEx.API.Search.get_search_history()
      {:ok, recent} = PlEx.API.Search.get_search_history(limit: 10)
  """
  @spec get_search_history(keyword()) :: {:ok, [Search.HistoryEntry.t()]} | {:error, term()}
  def get_search_history(opts \\ []) do
    with :ok <- require_feature(:activity_monitoring, opts) do
      path = "/hubs/search/history"
      params = build_list_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      request_with_schema(:pms, :get, path, Search.HistoryEntry, request_opts)
    end
  end

  # Private helper functions

  defp get_search_endpoint_and_params(query, opts) do
    {:ok, version} = get_or_detect_version(opts)

    if version_supports_enhanced_search?(version) and not opts[:force_basic] do
      # Use enhanced search endpoint
      path = "/hubs/search"
      params = build_enhanced_search_params(query, opts)
      {:ok, path, params}
    else
      # Use basic search endpoint
      path = "/search"
      params = build_basic_search_params(query, opts)
      {:ok, path, params}
    end
  end

  defp version_supports_enhanced_search?(version) do
    # Check if version supports enhanced search (v1.2.0+)
    case Version.compare(version, "1.2.0") do
      :gt -> true
      :eq -> true
      :lt -> false
    end
  rescue
    _ -> false
  end

  defp get_or_detect_version(opts) do
    case Keyword.get(opts, :version) do
      version when is_binary(version) -> {:ok, version}
      # Default fallback
      nil -> {:ok, "1.1.1"}
    end
  end

  defp build_basic_search_params(query, opts) do
    %{"query" => query}
    |> maybe_add_param("sectionId", opts[:section_id])
    |> maybe_add_param("type", type_to_number(opts[:type]))
    |> maybe_add_param("limit", opts[:limit])
  end

  defp build_enhanced_search_params(query, opts) do
    %{"query" => query}
    |> maybe_add_param("sectionId", opts[:section_id])
    |> maybe_add_param("type", type_to_number(opts[:type]))
    |> maybe_add_param("limit", opts[:limit])
    |> maybe_add_param("includeCollections", if(opts[:include_collections], do: "1", else: nil))
    |> maybe_add_param("includeExternal", if(opts[:include_external], do: "1", else: nil))
  end

  defp build_advanced_search_params(filters, opts) do
    base_params =
      %{}
      |> maybe_add_param("sectionId", opts[:section_id])
      |> maybe_add_param("limit", opts[:limit])

    Enum.reduce(filters, base_params, fn {key, value}, acc ->
      add_filter_param(acc, key, value)
    end)
  end

  defp build_search_within_params(query, opts) do
    %{"title" => query}
    |> maybe_add_param("type", type_to_number(opts[:type]))
    |> maybe_add_param("limit", opts[:limit])
  end

  defp build_people_search_params(query, opts) do
    %{
      "query" => query,
      # Person type
      "type" => "7"
    }
    |> maybe_add_param("role", role_to_string(opts[:role]))
    |> maybe_add_param("limit", opts[:limit])
  end

  defp build_trending_params(opts) do
    %{}
    |> maybe_add_param("period", period_to_string(opts[:period]))
    |> maybe_add_param("limit", opts[:limit])
  end

  defp add_filter_param(params, :title, value), do: Map.put(params, "title", value)
  defp add_filter_param(params, :year, {from, to}), do: Map.put(params, "year", "#{from}-#{to}")
  defp add_filter_param(params, :year, year), do: Map.put(params, "year", to_string(year))
  defp add_filter_param(params, :genre, value), do: Map.put(params, "genre", value)
  defp add_filter_param(params, :director, value), do: Map.put(params, "director", value)
  defp add_filter_param(params, :actor, value), do: Map.put(params, "actor", value)
  defp add_filter_param(params, :studio, value), do: Map.put(params, "studio", value)

  defp add_filter_param(params, :content_rating, value),
    do: Map.put(params, "contentRating", value)

  defp add_filter_param(params, :resolution, value), do: Map.put(params, "resolution", value)

  defp add_filter_param(params, :added_after, %Date{} = date),
    do: Map.put(params, "addedAfter", Date.to_string(date))

  defp add_filter_param(params, :added_before, %Date{} = date),
    do: Map.put(params, "addedBefore", Date.to_string(date))

  defp add_filter_param(params, key, value), do: Map.put(params, to_string(key), to_string(value))

  defp extract_suggestions_from_hubs(hubs) do
    hubs
    |> Enum.flat_map(&extract_metadata_titles_from_hub/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp extract_metadata_titles_from_hub(hub) do
    case Map.get(hub, "Metadata") do
      items when is_list(items) ->
        Enum.map(items, fn item -> Map.get(item, "title", "") end)

      item when is_map(item) ->
        [Map.get(item, "title", "")]

      _ ->
        []
    end
  end

  defp extract_trending_terms(hubs) do
    hubs
    |> Enum.flat_map(&extract_titles_from_hub/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp extract_titles_from_hub(hub) do
    case Map.get(hub, "Directory") do
      items when is_list(items) ->
        Enum.map(items, fn item -> Map.get(item, "title", "") end)

      item when is_map(item) ->
        [Map.get(item, "title", "")]

      _ ->
        []
    end
  end

  defp type_to_number(:movie), do: "1"
  defp type_to_number(:show), do: "2"
  defp type_to_number(:season), do: "3"
  defp type_to_number(:episode), do: "4"
  defp type_to_number(:trailer), do: "5"
  defp type_to_number(:comic), do: "6"
  defp type_to_number(:person), do: "7"
  defp type_to_number(:artist), do: "8"
  defp type_to_number(:album), do: "9"
  defp type_to_number(:track), do: "10"
  defp type_to_number(:photo_album), do: "11"
  defp type_to_number(:photo), do: "13"
  defp type_to_number(:clip), do: "14"
  defp type_to_number(:playlist_video), do: "15"
  defp type_to_number(:playlist_audio), do: "16"
  defp type_to_number(nil), do: nil
  defp type_to_number(other), do: to_string(other)

  defp role_to_string(:director), do: "director"
  defp role_to_string(:actor), do: "actor"
  defp role_to_string(:writer), do: "writer"
  defp role_to_string(:producer), do: "producer"
  defp role_to_string(nil), do: nil
  defp role_to_string(other), do: to_string(other)

  defp period_to_string(:day), do: "day"
  defp period_to_string(:week), do: "week"
  defp period_to_string(:month), do: "month"
  defp period_to_string(:year), do: "year"
  defp period_to_string(nil), do: nil
  defp period_to_string(other), do: to_string(other)

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Map.put(params, key, to_string(value))
end
