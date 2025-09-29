defmodule PlEx.API.Library do
  @moduledoc """
  Library management API for Plex Media Server.

  Provides functions to manage library sections, scan for new content,
  and retrieve media items from libraries with version-aware adaptations.
  """

  import PlEx.API.Base
  alias PlEx.Schemas.Library

  @doc """
  Gets all library sections from the Plex Media Server.

  ## Version Compatibility
  - v1.1.1+: Basic library listing
  - v1.2.0+: Includes collection counts and hub identifiers

  ## Examples

      {:ok, sections} = PlEx.API.Library.get_sections()
      {:ok, sections} = PlEx.API.Library.get_sections(include_details: true)
  """
  @spec get_sections(keyword()) :: {:ok, [Library.Section.t()]} | {:error, term()}
  def get_sections(opts \\ []) do
    with :ok <- require_feature(:library_sections, opts) do
      params = build_sections_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      case request_with_schema(:pms, :get, "/library/sections", Library.Section, request_opts) do
        {:ok, sections} when is_list(sections) -> {:ok, sections}
        {:ok, single_section} -> {:ok, [single_section]}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Gets a specific library section by its key.

  ## Examples

      {:ok, section} = PlEx.API.Library.get_section("1")
      {:ok, section} = PlEx.API.Library.get_section("movies")
  """
  @spec get_section(String.t(), keyword()) :: {:ok, Library.Section.t()} | {:error, term()}
  def get_section(section_key, opts \\ []) when is_binary(section_key) do
    with :ok <- require_feature(:library_sections, opts) do
      path = "/library/sections/#{section_key}"

      case request_with_schema(:pms, :get, path, Library.Section, opts) do
        {:ok, [section]} -> {:ok, section}
        {:ok, section} when is_struct(section) -> {:ok, section}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Gets all items from a library section.

  ## Options

  - `:type` - Filter by media type (`:movie`, `:show`, `:episode`, etc.)
  - `:sort` - Sort field and direction (`{:title, :asc}`, `{:added_at, :desc}`)
  - `:limit` - Maximum number of items to return
  - `:offset` - Number of items to skip (for pagination)
  - `:filters` - Map of additional filters

  ## Examples

      {:ok, movies} = PlEx.API.Library.get_items("1")
      {:ok, recent} = PlEx.API.Library.get_items("1", sort: {:added_at, :desc}, limit: 20)
      {:ok, action} = PlEx.API.Library.get_items("1", filters: %{genre: "Action"})
  """
  @spec get_items(String.t(), keyword()) :: {:ok, [Library.MediaItem.t()]} | {:error, term()}
  def get_items(section_key, opts \\ []) when is_binary(section_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/library/sections/#{section_key}/all"
      params = build_items_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      case request_with_schema(:pms, :get, path, Library.MediaItem, request_opts) do
        {:ok, items} when is_list(items) -> {:ok, items}
        {:ok, single_item} -> {:ok, [single_item]}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Gets recently added items from a library section.

  ## Examples

      {:ok, recent} = PlEx.API.Library.get_recently_added("1")
      {:ok, recent} = PlEx.API.Library.get_recently_added("1", limit: 10)
  """
  @spec get_recently_added(String.t(), keyword()) ::
          {:ok, [Library.MediaItem.t()]} | {:error, term()}
  def get_recently_added(section_key, opts \\ []) when is_binary(section_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/library/sections/#{section_key}/recentlyAdded"
      params = build_list_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      request_with_schema(:pms, :get, path, Library.MediaItem, request_opts)
    end
  end

  @doc """
  Triggers a library scan for new content.

  ## Options

  - `:force` - Force a full rescan (default: false)
  - `:deep` - Perform deep analysis of media files (default: false)

  ## Examples

      :ok = PlEx.API.Library.scan_section("1")
      :ok = PlEx.API.Library.scan_section("1", force: true)
  """
  @spec scan_section(String.t(), keyword()) :: :ok | {:error, term()}
  def scan_section(section_key, opts \\ []) when is_binary(section_key) do
    with :ok <- require_feature(:library_sections, opts) do
      path = "/library/sections/#{section_key}/refresh"
      params = build_scan_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :get, path, request_opts) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Gets collections from a library section.

  Only available in v1.2.0+. Returns an error for older versions.

  ## Examples

      {:ok, collections} = PlEx.API.Library.get_collections("1")
      {:ok, collections} = PlEx.API.Library.get_collections("1", sort: {:title, :asc})
  """
  @spec get_collections(String.t(), keyword()) ::
          {:ok, [Library.Collection.t()]} | {:error, term()}
  def get_collections(section_key, opts \\ []) when is_binary(section_key) do
    with :ok <- require_feature(:collections, opts) do
      path = "/library/sections/#{section_key}/collections"
      params = build_list_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      request_with_schema(:pms, :get, path, Library.Collection, request_opts)
    end
  end

  @doc """
  Creates a new collection in a library section.

  Only available in v1.2.0+.

  ## Options

  - `:summary` - Description of the collection
  - `:smart` - Whether this is a smart collection (v1.3.0+)
  - `:mode` - Collection display mode (v1.3.0+)

  ## Examples

      {:ok, collection} = PlEx.API.Library.create_collection("1", "Marvel Movies")
      {:ok, collection} = PlEx.API.Library.create_collection("1", "Action Films",
        summary: "High-octane action movies")
  """
  @spec create_collection(String.t(), String.t(), keyword()) ::
          {:ok, Library.Collection.t()} | {:error, term()}
  def create_collection(section_key, title, opts \\ [])
      when is_binary(section_key) and is_binary(title) do
    with :ok <- require_feature(:collections, opts) do
      path = "/library/sections/#{section_key}/collections"
      params = build_collection_params(title, opts)
      request_opts = Keyword.put(opts, :params, params)

      case request_with_schema(:pms, :post, path, Library.Collection, request_opts) do
        {:ok, [collection]} -> {:ok, collection}
        {:ok, collection} when is_struct(collection) -> {:ok, collection}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Gets on deck items (continue watching) from a library section.

  ## Version Notes

  - v1.1.1: Uses `/library/sections/{key}/onDeck`
  - v1.2.0+: Deprecated, suggests using hubs instead
  - v1.3.0+: Endpoint removed, must use hubs

  ## Examples

      {:ok, on_deck} = PlEx.API.Library.get_on_deck("1")
  """
  @spec get_on_deck(String.t(), keyword()) :: {:ok, [Library.MediaItem.t()]} | {:error, term()}
  def get_on_deck(section_key, opts \\ []) when is_binary(section_key) do
    path = "/library/sections/#{section_key}/onDeck"

    case check_endpoint_availability(path, opts) do
      :ok ->
        request_with_schema(:pms, :get, path, Library.MediaItem, opts)

      {:warning, _deprecation_info} ->
        # Endpoint is deprecated but still works
        request_with_schema(:pms, :get, path, Library.MediaItem, opts)

      {:error, %{removal_info: info}} ->
        # Endpoint is removed, suggest alternative
        case info[:replacement] do
          replacement_path when is_binary(replacement_path) ->
            {:error,
             PlEx.Error.config_error(:endpoint_removed_use_alternative, %{
               original: path,
               alternative: replacement_path,
               message: "Use PlEx.API.Hubs.get_on_deck/1 instead"
             })}

          _ ->
            {:error, PlEx.Error.config_error(:endpoint_removed, %{endpoint: path})}
        end
    end
  end

  @doc """
  Gets all items from a library section with automatic pagination.

  This function handles pagination automatically and returns all items.
  Use with caution on large libraries.

  ## Examples

      {:ok, all_movies} = PlEx.API.Library.get_all_items("1")
      {:ok, all_shows} = PlEx.API.Library.get_all_items("2", type: :show)
  """
  @spec get_all_items(String.t(), keyword()) :: {:ok, [Library.MediaItem.t()]} | {:error, term()}
  def get_all_items(section_key, opts \\ []) when is_binary(section_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/library/sections/#{section_key}/all"
      params = build_items_params(opts)

      request_opts =
        opts
        |> Keyword.put(:params, params)
        |> Keyword.put(:response_schema, Library.MediaItem)

      paginated_request(:pms, :get, path, request_opts)
    end
  end

  # Private helper functions

  defp build_sections_params(opts) do
    base_params = %{}

    base_params
    |> maybe_add_include_details(opts)
    |> maybe_add_include_collections(opts)
  end

  defp build_items_params(opts) do
    build_list_params(opts)
    |> maybe_add_type_filter(opts)
    |> maybe_add_unwatched_filter(opts)
  end

  defp build_scan_params(opts) do
    %{}
    |> maybe_add_param("force", if(opts[:force], do: "1", else: nil))
    |> maybe_add_param("deep", if(opts[:deep], do: "1", else: nil))
  end

  defp build_collection_params(title, opts) do
    %{"title" => title}
    |> maybe_add_param("summary", opts[:summary])
    |> maybe_add_param("smart", if(opts[:smart], do: "1", else: nil))
    |> maybe_add_param("collectionMode", opts[:mode])
  end

  defp maybe_add_include_details(params, opts) do
    if opts[:include_details] do
      Map.put(params, "includeDetails", "1")
    else
      params
    end
  end

  defp maybe_add_include_collections(params, opts) do
    if opts[:include_collections] do
      Map.put(params, "includeCollections", "1")
    else
      params
    end
  end

  defp maybe_add_type_filter(params, opts) do
    case opts[:type] do
      type when is_atom(type) -> Map.put(params, "type", type_to_number(type))
      _ -> params
    end
  end

  defp maybe_add_unwatched_filter(params, opts) do
    if opts[:unwatched] do
      Map.put(params, "unwatched", "1")
    else
      params
    end
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Map.put(params, key, value)

  # Map media types to Plex type numbers
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
  defp type_to_number(other), do: to_string(other)
end
