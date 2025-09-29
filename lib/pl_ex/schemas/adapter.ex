defmodule PlEx.Schemas.Adapter do
  @moduledoc """
  Schema adaptation layer for handling version differences.

  This module provides functions to adapt API responses to the appropriate
  schema format based on the API version, ensuring consistent data structures
  across different Plex API versions.
  """

  alias PlEx.{Version, Error}

  @doc """
  Adapts an API response to the appropriate schema for the given version.

  ## Examples

      response = %{"MediaContainer" => %{"Directory" => [...]}}
      {:ok, adapted} = PlEx.Schemas.Adapter.adapt_response(
        response,
        PlEx.Schemas.Library.SectionList,
        "1.2.0"
      )
  """
  @spec adapt_response(map(), module(), String.t()) :: {:ok, struct()} | {:error, term()}
  def adapt_response(response, schema_module, version) when is_map(response) do
    with :ok <- validate_schema_version_compatibility(schema_module, version),
         {:ok, normalized_response} <- normalize_response_format(response, version),
         {:ok, adapted_data} <-
           apply_version_adaptations(normalized_response, schema_module, version) do
      create_schema_struct(adapted_data, schema_module, version)
    end
  end

  @doc """
  Adapts a list of API responses to schema structs.

  Useful for endpoints that return arrays of items.
  """
  @spec adapt_response_list([map()], module(), String.t()) :: {:ok, [struct()]} | {:error, term()}
  def adapt_response_list(response_list, schema_module, version) when is_list(response_list) do
    results =
      Enum.map(response_list, fn response ->
        adapt_response(response, schema_module, version)
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        structs = Enum.map(results, fn {:ok, struct} -> struct end)
        {:ok, structs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extracts items from a MediaContainer response and adapts them.

  Most Plex API responses are wrapped in a MediaContainer structure.
  """
  @spec adapt_media_container(map(), module(), String.t()) :: {:ok, [struct()]} | {:error, term()}
  def adapt_media_container(response, item_schema_module, version) do
    case extract_items_from_container(response) do
      {:ok, items} -> adapt_response_list(items, item_schema_module, version)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the appropriate schema module for a response type and version.

  Some response types may have different schemas in different versions.
  """
  @spec get_schema_for_response(atom(), String.t()) :: {:ok, module()} | {:error, term()}
  def get_schema_for_response(response_type, version) do
    case {response_type, version} do
      {:library_sections, _} -> {:ok, PlEx.Schemas.Library.Section}
      {:media_items, _} -> {:ok, PlEx.Schemas.Library.MediaItem}
      {:collections, v} when v >= "1.2.0" -> {:ok, PlEx.Schemas.Library.Collection}
      {:collections, _} -> {:error, Error.config_error(:collections_not_supported)}
      _ -> {:error, Error.config_error(:unknown_response_type)}
    end
  end

  # Private functions

  defp validate_schema_version_compatibility(schema_module, version) do
    if function_exported?(schema_module, :supported_in_version?, 1) do
      case schema_module.supported_in_version?(version) do
        true ->
          :ok

        false ->
          {:error,
           Error.config_error(:schema_not_supported_in_version, %{
             schema: schema_module,
             version: version
           })}
      end
    else
      :ok
    end
  end

  defp normalize_response_format(response, version) do
    # Apply version-specific response normalization
    case Version.Adapter.adapt_response(response, version) do
      {:ok, adapted} -> {:ok, adapted}
      {:error, reason} -> {:error, Error.invalid_response(:adaptation_failed, %{reason: reason})}
    end
  end

  defp apply_version_adaptations(response, schema_module, version) do
    # Apply schema-specific adaptations based on version
    adapted_response =
      response
      |> normalize_field_names(version)
      |> add_version_specific_fields(schema_module, version)
      |> remove_unsupported_fields(schema_module, version)

    {:ok, adapted_response}
  end

  defp create_schema_struct(data, schema_module, version) do
    if function_exported?(schema_module, :from_api_response, 2) do
      {:ok, schema_module.from_api_response(data, version)}
    else
      # Fallback to basic struct creation
      {:ok, struct(schema_module, normalize_struct_fields(data))}
    end
  end

  defp extract_items_from_container(response) do
    case response do
      %{"MediaContainer" => container} ->
        extract_items_from_media_container(container)

      %{} = direct_items ->
        {:ok, [direct_items]}

      items when is_list(items) ->
        {:ok, items}

      _ ->
        {:error, Error.invalid_response(:invalid_container_format)}
    end
  end

  defp extract_items_from_media_container(container) do
    # Try different possible item keys in MediaContainer
    item_keys = ["Directory", "Metadata", "Video", "Track", "Photo", "Hub"]

    case find_items_in_container(container, item_keys) do
      {:ok, items} -> {:ok, items}
      # Empty container
      :not_found -> {:ok, []}
    end
  end

  defp find_items_in_container(container, [key | rest_keys]) do
    case Map.get(container, key) do
      items when is_list(items) -> {:ok, items}
      nil -> find_items_in_container(container, rest_keys)
      single_item when is_map(single_item) -> {:ok, [single_item]}
    end
  end

  defp find_items_in_container(_container, []), do: :not_found

  defp normalize_field_names(data, version) when is_map(data) do
    case version do
      v when v >= "1.2.0" ->
        # v1.2.0+ uses consistent camelCase
        data
        |> rename_field("library_section_id", "librarySectionId")
        |> rename_field("rating_key", "ratingKey")
        |> rename_field("parent_rating_key", "parentRatingKey")
        |> rename_field("grandparent_rating_key", "grandparentRatingKey")
        |> rename_field("added_at", "addedAt")
        |> rename_field("updated_at", "updatedAt")
        |> rename_field("created_at", "createdAt")
        |> rename_field("child_count", "childCount")

      _ ->
        # v1.1.1 may use mixed naming conventions
        data
    end
  end

  defp normalize_field_names(data, _version), do: data

  defp add_version_specific_fields(data, schema_module, version) when is_map(data) do
    case {schema_module, version} do
      {PlEx.Schemas.Library.Section, v} when v >= "1.2.0" ->
        data
        |> Map.put_new("collectionCount", 0)
        |> Map.put_new("hubIdentifier", generate_hub_identifier(data))

      {PlEx.Schemas.Library.MediaItem, v} when v >= "1.2.0" ->
        data
        |> Map.put_new("collectionTags", [])
        |> Map.put_new("hubIdentifier", generate_hub_identifier(data))

      {PlEx.Schemas.Library.Collection, v} when v >= "1.3.0" ->
        data
        |> Map.put_new("smart", false)
        |> Map.put_new("collectionMode", "default")

      _ ->
        data
    end
  end

  defp add_version_specific_fields(data, _schema_module, _version), do: data

  defp remove_unsupported_fields(data, schema_module, version) when is_map(data) do
    case {schema_module, version} do
      {PlEx.Schemas.Library.Section, v} when v < "1.2.0" ->
        data
        |> Map.delete("collectionCount")
        |> Map.delete("hubIdentifier")

      {PlEx.Schemas.Library.MediaItem, v} when v < "1.2.0" ->
        data
        |> Map.delete("collectionTags")
        |> Map.delete("hubIdentifier")

      {PlEx.Schemas.Library.Collection, v} when v < "1.3.0" ->
        data
        |> Map.delete("smart")
        |> Map.delete("collectionMode")

      _ ->
        data
    end
  end

  defp remove_unsupported_fields(data, _schema_module, _version), do: data

  defp normalize_struct_fields(data) when is_map(data) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      normalized_key = normalize_struct_field_name(key)
      Map.put(acc, normalized_key, value)
    end)
  end

  defp normalize_struct_field_name(key) when is_binary(key) do
    case key do
      "ratingKey" -> :rating_key
      "parentRatingKey" -> :parent_rating_key
      "grandparentRatingKey" -> :grandparent_rating_key
      "librarySectionId" -> :library_section_id
      "addedAt" -> :added_at
      "updatedAt" -> :updated_at
      "createdAt" -> :created_at
      "childCount" -> :child_count
      "collectionCount" -> :collection_count
      "hubIdentifier" -> :hub_identifier
      "collectionTags" -> :collection_tags
      "collectionMode" -> :collection_mode
      other -> String.to_atom(other)
    end
  end

  defp normalize_struct_field_name(key) when is_atom(key), do: key

  defp rename_field(data, old_key, new_key) when is_map(data) do
    case Map.pop(data, old_key) do
      {nil, data} -> data
      {value, data} -> Map.put(data, new_key, value)
    end
  end

  defp generate_hub_identifier(data) when is_map(data) do
    # Generate a hub identifier based on the item type and key
    case {Map.get(data, "type"), Map.get(data, "key")} do
      {type, key} when is_binary(type) and is_binary(key) ->
        "#{type}.#{String.replace(key, "/", ".")}"

      _ ->
        nil
    end
  end
end
