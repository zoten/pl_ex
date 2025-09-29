defmodule PlEx.API.Media do
  @moduledoc """
  Media item management API for Plex Media Server.

  Provides functions to manage individual media items including metadata retrieval,
  playback state management, rating, and media file operations with version-aware adaptations.
  """

  import PlEx.API.Base
  alias PlEx.Schemas.Media
  alias PlEx.Error

  @doc """
  Gets metadata for a specific media item by its rating key.

  ## Examples

      {:ok, movie} = PlEx.API.Media.get_metadata("12345")
      {:ok, episode} = PlEx.API.Media.get_metadata("67890", include_children: true)
  """
  @spec get_metadata(String.t(), keyword()) :: {:ok, Media.Item.t()} | {:error, term()}
  def get_metadata(rating_key, opts \\ []) when is_binary(rating_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/library/metadata/#{rating_key}"
      params = build_metadata_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      case request_with_schema(:pms, :get, path, Media.Item, request_opts) do
        {:ok, [item]} -> {:ok, item}
        {:ok, item} when is_struct(item) -> {:ok, item}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Gets children of a media item (e.g., episodes of a show, tracks of an album).

  ## Examples

      {:ok, episodes} = PlEx.API.Media.get_children("12345")
      {:ok, tracks} = PlEx.API.Media.get_children("67890", sort: {:track, :asc})
  """
  @spec get_children(String.t(), keyword()) :: {:ok, [Media.Item.t()]} | {:error, term()}
  def get_children(rating_key, opts \\ []) when is_binary(rating_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/library/metadata/#{rating_key}/children"
      params = build_list_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      request_with_schema(:pms, :get, path, Media.Item, request_opts)
    end
  end

  @doc """
  Marks a media item as watched.

  ## Examples

      :ok = PlEx.API.Media.mark_watched("12345")
  """
  @spec mark_watched(String.t(), keyword()) :: :ok | {:error, term()}
  def mark_watched(rating_key, opts \\ []) when is_binary(rating_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/:/scrobble"
      params = %{"key" => rating_key, "identifier" => "com.plexapp.plugins.library"}
      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :get, path, request_opts) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Marks a media item as unwatched.

  ## Examples

      :ok = PlEx.API.Media.mark_unwatched("12345")
  """
  @spec mark_unwatched(String.t(), keyword()) :: :ok | {:error, term()}
  def mark_unwatched(rating_key, opts \\ []) when is_binary(rating_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/:/unscrobble"
      params = %{"key" => rating_key, "identifier" => "com.plexapp.plugins.library"}
      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :get, path, request_opts) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Sets the playback progress for a media item.

  ## Options

  - `:time` - Progress time in milliseconds (required)
  - `:state` - Playback state (`:playing`, `:paused`, `:stopped`)

  ## Examples

      :ok = PlEx.API.Media.set_progress("12345", time: 300000, state: :paused)
  """
  @spec set_progress(String.t(), keyword()) :: :ok | {:error, term()}
  def set_progress(rating_key, opts) when is_binary(rating_key) and is_list(opts) do
    with :ok <- require_feature(:media_metadata, opts),
         {:ok, time} <- get_required_option(opts, :time) do
      path = "/:/progress"
      params = build_progress_params(rating_key, time, opts)
      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :get, path, request_opts) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Sets a rating for a media item.

  ## Examples

      :ok = PlEx.API.Media.rate("12345", 8.5)
      :ok = PlEx.API.Media.rate("12345", 4, scale: :stars)  # 4 out of 5 stars
  """
  @spec rate(String.t(), number(), keyword()) :: :ok | {:error, term()}
  def rate(rating_key, rating, opts \\ []) when is_binary(rating_key) and is_number(rating) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/:/rate"
      params = build_rating_params(rating_key, rating, opts)
      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :get, path, request_opts) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Removes a rating from a media item.

  ## Examples

      :ok = PlEx.API.Media.unrate("12345")
  """
  @spec unrate(String.t(), keyword()) :: :ok | {:error, term()}
  def unrate(rating_key, opts \\ []) when is_binary(rating_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/:/unrate"
      params = %{"key" => rating_key, "identifier" => "com.plexapp.plugins.library"}
      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :get, path, request_opts) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Gets related media items (similar movies, related shows, etc.).

  Only available in v1.2.0+.

  ## Examples

      {:ok, related} = PlEx.API.Media.get_related("12345")
      {:ok, similar} = PlEx.API.Media.get_related("12345", type: :similar)
  """
  @spec get_related(String.t(), keyword()) :: {:ok, [Media.Item.t()]} | {:error, term()}
  def get_related(rating_key, opts \\ []) when is_binary(rating_key) do
    # Related items use the hubs system
    with :ok <- require_feature(:hubs, opts) do
      path = "/library/metadata/#{rating_key}/related"
      params = build_related_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      request_with_schema(:pms, :get, path, Media.Item, request_opts)
    end
  end

  @doc """
  Gets media parts and streams information for a media item.

  Useful for accessing direct file paths, stream information, and technical details.

  ## Examples

      {:ok, parts} = PlEx.API.Media.get_parts("12345")
  """
  @spec get_parts(String.t(), keyword()) :: {:ok, [Media.Part.t()]} | {:error, term()}
  def get_parts(rating_key, opts \\ []) when is_binary(rating_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      # Get full metadata including media parts
      case get_metadata(rating_key, Keyword.put(opts, :include_media, true)) do
        {:ok, %{media: media}} when is_list(media) ->
          parts = Enum.flat_map(media, fn m -> Map.get(m, :parts, []) end)
          {:ok, parts}

        {:ok, %{media: %{} = media}} ->
          parts = Map.get(media, :parts, [])
          {:ok, parts}

        {:ok, _item} ->
          {:ok, []}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Refreshes metadata for a media item from external sources.

  ## Options

  - `:force` - Force a complete refresh (default: false)

  ## Examples

      :ok = PlEx.API.Media.refresh_metadata("12345")
      :ok = PlEx.API.Media.refresh_metadata("12345", force: true)
  """
  @spec refresh_metadata(String.t(), keyword()) :: :ok | {:error, term()}
  def refresh_metadata(rating_key, opts \\ []) when is_binary(rating_key) do
    with :ok <- require_feature(:media_metadata, opts) do
      path = "/library/metadata/#{rating_key}/refresh"
      params = build_refresh_params(opts)
      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :get, path, request_opts) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Adds a media item to a collection.

  Only available in v1.2.0+.

  ## Examples

      :ok = PlEx.API.Media.add_to_collection("12345", "67890")
  """
  @spec add_to_collection(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def add_to_collection(rating_key, collection_key, opts \\ [])
      when is_binary(rating_key) and is_binary(collection_key) do
    with :ok <- require_feature(:collections, opts) do
      path = "/library/collections/#{collection_key}/items"

      params = %{
        "uri" =>
          "server://#{get_server_id(opts)}/com.plexapp.plugins.library/library/metadata/#{rating_key}"
      }

      request_opts = Keyword.put(opts, :params, params)

      case request(:pms, :put, path, request_opts) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Removes a media item from a collection.

  Only available in v1.2.0+.

  ## Examples

      :ok = PlEx.API.Media.remove_from_collection("12345", "67890")
  """
  @spec remove_from_collection(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def remove_from_collection(rating_key, collection_key, opts \\ [])
      when is_binary(rating_key) and is_binary(collection_key) do
    with :ok <- require_feature(:collections, opts) do
      path = "/library/collections/#{collection_key}/items/#{rating_key}"

      case request(:pms, :delete, path, opts) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Private helper functions

  defp build_metadata_params(opts) do
    %{}
    |> maybe_add_param("includeChildren", if(opts[:include_children], do: "1", else: nil))
    |> maybe_add_param("includeMedia", if(opts[:include_media], do: "1", else: nil))
    |> maybe_add_param("includeRelated", if(opts[:include_related], do: "1", else: nil))
    |> maybe_add_param("includeExtras", if(opts[:include_extras], do: "1", else: nil))
    |> maybe_add_param("includeReviews", if(opts[:include_reviews], do: "1", else: nil))
  end

  defp build_progress_params(rating_key, time, opts) do
    %{
      "key" => rating_key,
      "identifier" => "com.plexapp.plugins.library",
      "time" => to_string(time)
    }
    |> maybe_add_param("state", state_to_string(opts[:state]))
  end

  defp build_rating_params(rating_key, rating, opts) do
    scale = opts[:scale] || :decimal
    normalized_rating = normalize_rating(rating, scale)

    %{
      "key" => rating_key,
      "identifier" => "com.plexapp.plugins.library",
      "rating" => to_string(normalized_rating)
    }
  end

  defp build_related_params(opts) do
    %{}
    |> maybe_add_param("type", opts[:type])
    |> maybe_add_param("count", opts[:count])
  end

  defp build_refresh_params(opts) do
    %{}
    |> maybe_add_param("force", if(opts[:force], do: "1", else: nil))
  end

  defp get_required_option(opts, key) do
    case Keyword.get(opts, key) do
      nil -> {:error, Error.config_error(:missing_required_option, %{option: key})}
      value -> {:ok, value}
    end
  end

  defp get_server_id(opts) do
    # In a real implementation, this would get the server machine identifier
    # For now, we'll use a placeholder
    opts[:server_id] || "localhost"
  end

  defp state_to_string(:playing), do: "playing"
  defp state_to_string(:paused), do: "paused"
  defp state_to_string(:stopped), do: "stopped"
  defp state_to_string(nil), do: nil
  defp state_to_string(other), do: to_string(other)

  defp normalize_rating(rating, :decimal) when rating >= 0 and rating <= 10, do: rating
  defp normalize_rating(rating, :stars) when rating >= 0 and rating <= 5, do: rating * 2
  defp normalize_rating(rating, :percentage) when rating >= 0 and rating <= 100, do: rating / 10
  defp normalize_rating(rating, _scale), do: rating

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Map.put(params, key, to_string(value))
end
