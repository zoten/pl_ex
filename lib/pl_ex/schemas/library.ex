defmodule PlEx.Schemas.Library do
  @moduledoc """
  Schema definitions for Plex Library API.

  Defines the structure of library sections, media items, and related objects
  with version-specific adaptations.
  """

  defmodule Section do
    @moduledoc "A library section (Movies, TV Shows, etc.)"

    @type t :: %__MODULE__{
            key: String.t() | nil,
            title: String.t() | nil,
            type: String.t() | nil,
            agent: String.t() | nil,
            scanner: String.t() | nil,
            language: String.t() | nil,
            uuid: String.t() | nil,
            created_at: String.t() | nil,
            updated_at: String.t() | nil,
            collection_count: integer() | nil,
            hub_identifier: String.t() | nil
          }

    defstruct [
      :key,
      :title,
      :type,
      :agent,
      :scanner,
      :language,
      :uuid,
      :created_at,
      :updated_at,
      # Added in v1.2.0
      :collection_count,
      # Added in v1.2.0
      :hub_identifier
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

    def supported_in_version?(version) do
      PlEx.Version.Compatibility.supports_version?(version, :library_sections)
    end

    defp normalize_fields(data) when is_map(data) do
      Enum.reduce(data, %{}, fn {key, value}, acc ->
        normalized_key = normalize_field_name(key)
        Map.put(acc, normalized_key, value)
      end)
    end

    defp normalize_field_name(key) when is_binary(key) do
      case key do
        "createdAt" -> :created_at
        "updatedAt" -> :updated_at
        "collectionCount" -> :collection_count
        "hubIdentifier" -> :hub_identifier
        other -> String.to_atom(other)
      end
    end

    defp normalize_field_name(key) when is_atom(key), do: key
  end

  defmodule MediaItem do
    @moduledoc "A media item (movie, episode, track, etc.)"

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
            collection_tags: list() | nil,
            hub_identifier: String.t() | nil
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
      # Version-specific fields
      # v1.2.0+
      :collection_tags,
      # v1.2.0+
      :hub_identifier
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

    def supported_in_version?(version) do
      PlEx.Version.Compatibility.supports_version?(version, :media_metadata)
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
        "librarySectionId" -> :library_section_id
        "addedAt" -> :added_at
        "updatedAt" -> :updated_at
        "collectionTags" -> :collection_tags
        "hubIdentifier" -> :hub_identifier
        other -> String.to_atom(other)
      end
    end

    defp normalize_field_name(key) when is_atom(key), do: key
  end

  defmodule Collection do
    @moduledoc "A collection of media items"

    @type t :: %__MODULE__{
            rating_key: String.t() | nil,
            key: String.t() | nil,
            title: String.t() | nil,
            type: String.t() | nil,
            child_count: integer() | nil,
            added_at: String.t() | nil,
            updated_at: String.t() | nil,
            thumb: String.t() | nil,
            art: String.t() | nil,
            smart: boolean() | nil,
            collection_mode: String.t() | nil
          }

    defstruct [
      :rating_key,
      :key,
      :title,
      :type,
      :child_count,
      :added_at,
      :updated_at,
      :thumb,
      :art,
      # v1.3.0+ fields
      :smart,
      :collection_mode
    ]

    def from_api_response(data, version \\ "1.2.0") do
      adapted_data = PlEx.Version.Adapter.adapt_response(data, version)

      normalized_data =
        case adapted_data do
          {:ok, normalized} -> normalized
          {:error, _} -> data
        end

      struct(__MODULE__, normalize_fields(normalized_data))
    end

    def supported_in_version?(version) do
      PlEx.Version.Compatibility.supports_version?(version, :collections)
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
        "childCount" -> :child_count
        "addedAt" -> :added_at
        "updatedAt" -> :updated_at
        "collectionMode" -> :collection_mode
        other -> String.to_atom(other)
      end
    end

    defp normalize_field_name(key) when is_atom(key), do: key
  end
end
