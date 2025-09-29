defmodule PlEx.Schemas.Base do
  @moduledoc """
  Base module for PlEx OpenAPI schemas.

  Provides common functionality and utilities for all schema modules,
  including version adaptation and validation helpers.
  """

  @doc """
  Macro to define a versioned schema.

  This macro sets up the basic structure for schemas that need to
  adapt across different API versions.
  """
  defmacro defschema(name, opts \\ [], do: block) do
    quote do
      defmodule unquote(name) do
        @moduledoc unquote(Keyword.get(opts, :description, ""))
        @minimum_version unquote(Keyword.get(opts, :minimum_version, "1.1.1"))
        @deprecated_in unquote(Keyword.get(opts, :deprecated_in))

        unquote(block)

        @doc """
        Creates a struct from API response data, adapting for version differences.
        """
        def from_api_response(data, version \\ "1.1.1") do
          adapted_data = PlEx.Version.Adapter.adapt_response(data, version)

          case adapted_data do
            {:ok, normalized_data} -> struct(__MODULE__, normalize_fields(normalized_data))
            {:error, _reason} -> struct(__MODULE__, normalize_fields(data))
          end
        end

        @doc """
        Checks if this schema is supported in the given version.
        """
        def supported_in_version?(version) do
          PlEx.Version.Compatibility.version_gte?(version, @minimum_version) and
            not deprecated_in_version?(version)
        end

        @doc """
        Checks if this schema is deprecated in the given version.
        """
        def deprecated_in_version?(version) do
          case @deprecated_in do
            nil ->
              false

            deprecated_version ->
              PlEx.Version.Compatibility.version_gte?(version, deprecated_version)
          end
        end

        # Private helper to normalize field names from API responses
        defp normalize_fields(data) when is_map(data) do
          # Convert string keys to atoms, handling common API field variations
          Enum.reduce(data, %{}, fn {key, value}, acc ->
            normalized_key = normalize_field_name(key)
            Map.put(acc, normalized_key, value)
          end)
        end

        defp normalize_fields(data), do: data

        defp normalize_field_name(key) when is_binary(key) do
          # Convert common API field name variations to our schema field names
          case key do
            "ratingKey" -> :rating_key
            "parentRatingKey" -> :parent_rating_key
            "librarySectionId" -> :library_section_id
            "addedAt" -> :added_at
            "updatedAt" -> :updated_at
            "createdAt" -> :created_at
            other -> String.to_atom(other)
          end
        end

        defp normalize_field_name(key) when is_atom(key), do: key
      end
    end
  end

  @doc """
  Common field definitions used across multiple schemas.
  """
  def common_fields do
    %{
      rating_key: %OpenApiSpex.Schema{
        type: :string,
        description: "Unique identifier for the item"
      },
      key: %OpenApiSpex.Schema{
        type: :string,
        description: "API path key for the item"
      },
      title: %OpenApiSpex.Schema{
        type: :string,
        description: "Display title"
      },
      type: %OpenApiSpex.Schema{
        type: :string,
        description: "Item type"
      },
      added_at: %OpenApiSpex.Schema{
        type: :integer,
        description: "Unix timestamp when item was added"
      },
      updated_at: %OpenApiSpex.Schema{
        type: :integer,
        description: "Unix timestamp when item was last updated"
      }
    }
  end

  @doc """
  Media container wrapper schema used by most Plex API responses.
  """
  def media_container_schema(content_schema) do
    %OpenApiSpex.Schema{
      type: :object,
      properties: %{
        MediaContainer: %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            size: %OpenApiSpex.Schema{type: :integer, description: "Number of items"},
            totalSize: %OpenApiSpex.Schema{
              type: :integer,
              description: "Total number of items available"
            },
            offset: %OpenApiSpex.Schema{type: :integer, description: "Offset for pagination"},
            identifier: %OpenApiSpex.Schema{type: :string, description: "Container identifier"},
            content: content_schema
          },
          required: [:size]
        }
      },
      required: [:MediaContainer]
    }
  end

  @doc """
  Validates that a schema is compatible with a given API version.
  """
  def validate_version_compatibility(schema_module, version) do
    if function_exported?(schema_module, :supported_in_version?, 1) do
      case schema_module.supported_in_version?(version) do
        true -> :ok
        false -> {:error, :schema_not_supported_in_version}
      end
    else
      # Assume compatible if no version info
      :ok
    end
  end

  @doc """
  Gets the appropriate schema module for a given version.

  Some schemas may have version-specific implementations.
  """
  def get_schema_for_version(base_schema, version) do
    # For now, return the base schema
    # Later we can implement version-specific schema selection
    case validate_version_compatibility(base_schema, version) do
      :ok -> {:ok, base_schema}
      {:error, reason} -> {:error, reason}
    end
  end
end
