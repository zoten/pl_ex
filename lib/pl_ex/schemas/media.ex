defmodule PlEx.Schemas.Media do
  @moduledoc """
  Schema definitions for Plex Media API.

  Defines the structure of media items, parts, and related objects
  with version-specific adaptations.
  """

  defmodule Item do
    @moduledoc "A media item with detailed metadata"

    @type t :: %__MODULE__{
            rating_key: String.t() | nil,
            key: String.t() | nil,
            parent_rating_key: String.t() | nil,
            grandparent_rating_key: String.t() | nil,
            title: String.t() | nil,
            type: String.t() | nil,
            summary: String.t() | nil,
            year: integer() | nil,
            duration: integer() | nil,
            added_at: String.t() | nil,
            updated_at: String.t() | nil,
            library_section_id: String.t() | nil,
            thumb: String.t() | nil,
            art: String.t() | nil,
            rating: float() | nil,
            view_count: integer() | nil,
            last_viewed_at: String.t() | nil,
            media: list() | map() | nil,
            genres: list() | nil,
            directors: list() | nil,
            writers: list() | nil,
            actors: list() | nil
          }

    defstruct [
      :rating_key,
      :key,
      :parent_rating_key,
      :grandparent_rating_key,
      :title,
      :type,
      :summary,
      :year,
      :duration,
      :added_at,
      :updated_at,
      :library_section_id,
      :thumb,
      :art,
      :rating,
      :view_count,
      :last_viewed_at,
      :media,
      :genres,
      :directors,
      :writers,
      :actors
    ]

    def from_api_response(data, version \\ "1.1.1") do
      adapted_data = PlEx.Version.Adapter.adapt_response(data, version)

      normalized_data =
        case adapted_data do
          {:ok, normalized} -> normalized
          {:error, _} -> data
        end

      struct(__MODULE__, normalize_fields(normalized_data))
    end

    defp normalize_fields(data) when is_map(data) do
      Enum.reduce(data, %{}, fn {key, value}, acc ->
        normalized_key = normalize_field_name(key)
        Map.put(acc, normalized_key, value)
      end)
    end

    defp normalize_field_name(key) when is_binary(key) do
      case key do
        "ratingKey" -> :rating_key
        "parentRatingKey" -> :parent_rating_key
        "grandparentRatingKey" -> :grandparent_rating_key
        "librarySectionID" -> :library_section_id
        "addedAt" -> :added_at
        "updatedAt" -> :updated_at
        "viewCount" -> :view_count
        "lastViewedAt" -> :last_viewed_at
        other -> String.to_atom(other)
      end
    end

    defp normalize_field_name(key) when is_atom(key), do: key
  end

  defmodule Part do
    @moduledoc "A media part (file) within a media item"

    @type t :: %__MODULE__{
            id: String.t() | nil,
            key: String.t() | nil,
            duration: integer() | nil,
            file: String.t() | nil,
            size: integer() | nil,
            container: String.t() | nil,
            video_profile: String.t() | nil,
            audio_profile: String.t() | nil,
            has_thumbnail: boolean() | nil,
            streams: list() | nil
          }

    defstruct [
      :id,
      :key,
      :duration,
      :file,
      :size,
      :container,
      :video_profile,
      :audio_profile,
      :has_thumbnail,
      :streams
    ]

    def from_api_response(data, version \\ "1.1.1") do
      adapted_data = PlEx.Version.Adapter.adapt_response(data, version)

      normalized_data =
        case adapted_data do
          {:ok, normalized} -> normalized
          {:error, _} -> data
        end

      struct(__MODULE__, normalize_fields(normalized_data))
    end

    defp normalize_fields(data) when is_map(data) do
      Enum.reduce(data, %{}, fn {key, value}, acc ->
        normalized_key = normalize_field_name(key)
        Map.put(acc, normalized_key, value)
      end)
    end

    defp normalize_field_name(key) when is_binary(key) do
      case key do
        "videoProfile" -> :video_profile
        "audioProfile" -> :audio_profile
        "hasThumbnail" -> :has_thumbnail
        other -> String.to_atom(other)
      end
    end

    defp normalize_field_name(key) when is_atom(key), do: key
  end
end
