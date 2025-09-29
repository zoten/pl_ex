defmodule PlEx.Schemas.Search do
  @moduledoc """
  Schema definitions for Plex Search API.

  Defines the structure of search results, persons, and related objects
  with version-specific adaptations.
  """

  defmodule Result do
    @moduledoc "A search result item"

    @type t :: %__MODULE__{
            rating_key: String.t() | nil,
            key: String.t() | nil,
            title: String.t() | nil,
            type: String.t() | nil,
            summary: String.t() | nil,
            year: integer() | nil,
            thumb: String.t() | nil,
            art: String.t() | nil,
            score: float() | nil,
            library_section_id: String.t() | nil,
            library_section_title: String.t() | nil,
            media_container_size: integer() | nil
          }

    defstruct [
      :rating_key,
      :key,
      :title,
      :type,
      :summary,
      :year,
      :thumb,
      :art,
      :score,
      :library_section_id,
      :library_section_title,
      :media_container_size
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
        "librarySectionID" -> :library_section_id
        "librarySectionTitle" -> :library_section_title
        "mediaContainerSize" -> :media_container_size
        other -> String.to_atom(other)
      end
    end

    defp normalize_field_name(key) when is_atom(key), do: key
  end

  defmodule Person do
    @moduledoc "A person (actor, director, writer) in search results"

    @type t :: %__MODULE__{
            rating_key: String.t() | nil,
            key: String.t() | nil,
            title: String.t() | nil,
            type: String.t() | nil,
            thumb: String.t() | nil,
            role: String.t() | nil,
            tag: String.t() | nil
          }

    defstruct [
      :rating_key,
      :key,
      :title,
      :type,
      :thumb,
      :role,
      :tag
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
        other -> String.to_atom(other)
      end
    end

    defp normalize_field_name(key) when is_atom(key), do: key
  end

  defmodule HistoryEntry do
    @moduledoc "A search history entry"

    @type t :: %__MODULE__{
            query: String.t() | nil,
            timestamp: String.t() | nil,
            results_count: integer() | nil,
            library_section_id: String.t() | nil
          }

    defstruct [
      :query,
      :timestamp,
      :results_count,
      :library_section_id
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
        "resultsCount" -> :results_count
        "librarySectionID" -> :library_section_id
        other -> String.to_atom(other)
      end
    end

    defp normalize_field_name(key) when is_atom(key), do: key
  end
end
