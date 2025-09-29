defmodule PlEx.Version.Adapter do
  @moduledoc """
  Version-specific adaptations for API requests and responses.

  This module handles the differences between API versions by providing
  adaptation functions that transform requests and responses to maintain
  compatibility across versions.
  """

  alias PlEx.{Error, Version}

  @type version :: String.t()
  @type request :: map()
  @type response :: map()
  @type adaptation_result :: {:ok, term()} | {:error, term()}

  @doc """
  Adapts a request for a specific API version.

  Transforms request parameters, headers, and body to match the
  expected format for the target API version.

  ## Examples

      request = %{method: :get, path: "/library/sections", params: %{}}
      {:ok, adapted} = PlEx.Version.Adapter.adapt_request(request, "1.2.0")
  """
  @spec adapt_request(request(), version()) :: adaptation_result()
  def adapt_request(request, version) when is_map(request) and is_binary(version) do
    case Version.Detector.supported_version?(version) do
      true -> do_adapt_request(request, version)
      false -> {:error, Error.config_error(:unsupported_version, %{version: version})}
    end
  end

  @doc """
  Adapts a response from a specific API version.

  Transforms response data to a normalized format that's consistent
  across all API versions.
  """
  @spec adapt_response(response(), version()) :: adaptation_result()
  def adapt_response(response, version) when is_map(response) and is_binary(version) do
    case Version.Detector.supported_version?(version) do
      true -> do_adapt_response(response, version)
      false -> {:error, Error.config_error(:unsupported_version, %{version: version})}
    end
  end

  @doc """
  Adapts an API endpoint path for a specific version.

  Some endpoints change between versions, this function maps
  old endpoints to new ones or adds version-specific parameters.
  """
  @spec adapt_endpoint(String.t(), version()) :: {:ok, String.t()} | {:error, term()}
  def adapt_endpoint(path, version) when is_binary(path) and is_binary(version) do
    case get_endpoint_mapping(path, version) do
      {:ok, adapted_path} -> {:ok, adapted_path}
      :no_change -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Adapts request parameters for version-specific requirements.

  Different versions may require different parameter names or formats.
  """
  @spec adapt_params(map(), String.t(), version()) :: {:ok, map()} | {:error, term()}
  def adapt_params(params, endpoint, version) when is_map(params) do
    case get_param_adaptations(endpoint, version) do
      [] -> {:ok, params}
      adaptations -> apply_param_adaptations(params, adaptations)
    end
  end

  @doc """
  Checks if an endpoint is available in a specific version.
  """
  @spec endpoint_available?(String.t(), version()) :: boolean()
  def endpoint_available?(path, version) do
    case get_endpoint_availability(path, version) do
      :available -> true
      # Still available but deprecated
      :deprecated -> true
      :unavailable -> false
    end
  end

  @doc """
  Returns deprecation information for an endpoint in a specific version.
  """
  @spec endpoint_deprecation_info(String.t(), version()) ::
          :not_deprecated | {:deprecated, map()} | {:removed, map()}
  def endpoint_deprecation_info(path, version) do
    case get_endpoint_availability(path, version) do
      :available -> :not_deprecated
      :deprecated -> {:deprecated, get_deprecation_details(path, version)}
      :unavailable -> {:removed, get_removal_details(path, version)}
    end
  end

  # Private functions - Request adaptations

  defp do_adapt_request(request, version) do
    with {:ok, adapted_path} <- adapt_endpoint(request[:path] || "", version),
         {:ok, adapted_params} <- adapt_params(request[:params] || %{}, adapted_path, version),
         {:ok, adapted_headers} <- adapt_headers(request[:headers] || [], version) do
      adapted_request =
        request
        |> Map.put(:path, adapted_path)
        |> Map.put(:params, adapted_params)
        |> Map.put(:headers, adapted_headers)
        |> add_version_specific_options(version)

      {:ok, adapted_request}
    end
  end

  defp adapt_headers(headers, version) do
    base_headers = headers
    version_headers = get_version_specific_headers(version)

    {:ok, base_headers ++ version_headers}
  end

  defp add_version_specific_options(request, version) do
    options = get_version_specific_options(version)
    Map.merge(request, options)
  end

  # Private functions - Response adaptations

  defp do_adapt_response(response, version) do
    case response do
      %{"MediaContainer" => container} ->
        adapt_media_container_response(container, version)

      %{} = direct_response ->
        adapt_direct_response(direct_response, version)
    end
  end

  defp adapt_media_container_response(container, version) do
    adapted_container =
      container
      |> normalize_field_names(version)
      |> add_missing_fields(version)
      |> transform_nested_objects(version)

    {:ok, %{"MediaContainer" => adapted_container}}
  end

  defp adapt_direct_response(response, version) do
    adapted_response =
      response
      |> normalize_field_names(version)
      |> add_missing_fields(version)
      |> transform_nested_objects(version)

    {:ok, adapted_response}
  end

  # Version-specific mappings and transformations

  defp get_endpoint_mapping(path, version) do
    mappings = %{
      # v1.1.1 -> v1.2.0 mappings
      "/library/onDeck" =>
        case version do
          v when v >= "1.2.0" -> {:ok, "/hubs/home/onDeck"}
          _ -> :no_change
        end,
      "/search" =>
        case version do
          v when v >= "1.2.0" -> {:ok, "/hubs/search"}
          _ -> :no_change
        end,

      # v1.2.0 -> v1.3.0 mappings
      "/butler/tasks" =>
        case version do
          v when v >= "1.3.0" -> {:ok, "/butler/v2/tasks"}
          _ -> :no_change
        end
    }

    Map.get(mappings, path, :no_change)
  end

  defp get_param_adaptations(endpoint, version) do
    case {endpoint, version} do
      {"/library/sections", v} when v >= "1.2.0" ->
        [
          {:rename, "includeCollections", "includeCollectionCounts"},
          {:add_default, "includeExternalMedia", "1"}
        ]

      {"/hubs/search", v} when v >= "1.2.0" ->
        [
          {:rename, "query", "searchQuery"},
          {:add_default, "searchTypes", "1,2,3,4"}
        ]

      _ ->
        []
    end
  end

  defp apply_param_adaptations(params, adaptations) do
    result = Enum.reduce(adaptations, params, &apply_single_adaptation/2)
    {:ok, result}
  end

  defp apply_single_adaptation(adaptation, acc) do
    case adaptation do
      {:rename, old_key, new_key} ->
        apply_rename_adaptation(acc, old_key, new_key)

      {:add_default, key, default_value} ->
        Map.put_new(acc, key, default_value)

      {:transform, key, transform_fn} ->
        apply_transform_adaptation(acc, key, transform_fn)
    end
  end

  defp apply_rename_adaptation(acc, old_key, new_key) do
    case Map.pop(acc, old_key) do
      {nil, acc} -> acc
      {value, acc} -> Map.put(acc, new_key, value)
    end
  end

  defp apply_transform_adaptation(acc, key, transform_fn) do
    case Map.get(acc, key) do
      nil -> acc
      value -> Map.put(acc, key, transform_fn.(value))
    end
  end

  defp get_version_specific_headers(version) do
    case version do
      v when v >= "1.3.0" ->
        [{"X-Plex-Features", "enhanced-search,collections-v2"}]

      v when v >= "1.2.0" ->
        [{"X-Plex-Features", "collections,hubs"}]

      _ ->
        []
    end
  end

  defp get_version_specific_options(version) do
    case version do
      v when v >= "1.2.0" ->
        %{timeout: 30_000, follow_redirects: true}

      _ ->
        %{timeout: 15_000}
    end
  end

  defp get_endpoint_availability(path, version) do
    availability_matrix = %{
      "/library/onDeck" => %{
        "1.1.1" => :available,
        "1.2.0" => :deprecated,
        "1.3.0" => :unavailable
      },
      "/hubs" => %{
        "1.1.1" => :unavailable,
        "1.2.0" => :available,
        "1.3.0" => :available
      },
      "/butler/v2/tasks" => %{
        "1.1.1" => :unavailable,
        "1.2.0" => :unavailable,
        "1.3.0" => :available
      }
    }

    case get_in(availability_matrix, [path, version]) do
      # Default to available if not specified
      nil -> :available
      status -> status
    end
  end

  defp get_deprecation_details(path, version) do
    %{
      deprecated_in: version,
      replacement: get_replacement_endpoint(path),
      removal_planned: get_removal_version(path),
      migration_guide: get_migration_guide_url(path)
    }
  end

  defp get_removal_details(path, version) do
    %{
      removed_in: version,
      replacement: get_replacement_endpoint(path),
      last_supported: get_last_supported_version(path)
    }
  end

  defp get_replacement_endpoint(path) do
    replacements = %{
      "/library/onDeck" => "/hubs/home/onDeck",
      "/search" => "/hubs/search",
      "/butler/tasks" => "/butler/v2/tasks"
    }

    Map.get(replacements, path)
  end

  defp get_removal_version(path) do
    removal_versions = %{
      "/library/onDeck" => "1.3.0",
      "/search" => "1.3.0"
    }

    Map.get(removal_versions, path)
  end

  defp get_last_supported_version(path) do
    last_supported = %{
      "/library/onDeck" => "1.2.0",
      "/search" => "1.2.0"
    }

    Map.get(last_supported, path, "1.1.1")
  end

  defp get_migration_guide_url(path) do
    "https://docs.plex.tv/migration/#{String.replace(path, "/", "-")}"
  end

  # Response normalization functions

  defp normalize_field_names(data, version) when is_map(data) do
    case version do
      v when v >= "1.2.0" ->
        # v1.2.0+ uses camelCase consistently
        data
        |> rename_field("library_section_id", "librarySectionId")
        |> rename_field("rating_key", "ratingKey")
        |> rename_field("parent_rating_key", "parentRatingKey")

      _ ->
        # v1.1.1 uses snake_case in some places
        data
    end
  end

  defp normalize_field_names(data, _version), do: data

  defp add_missing_fields(data, version) when is_map(data) do
    case version do
      v when v >= "1.2.0" ->
        # Add fields that were introduced in v1.2.0
        data
        |> Map.put_new("collectionCount", 0)
        |> Map.put_new("hubIdentifier", nil)

      _ ->
        data
    end
  end

  defp add_missing_fields(data, _version), do: data

  defp transform_nested_objects(data, version) when is_map(data) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      transformed_value =
        case value do
          list when is_list(list) ->
            Enum.map(list, &transform_nested_objects(&1, version))

          map when is_map(map) ->
            transform_nested_objects(map, version)

          other ->
            other
        end

      Map.put(acc, key, transformed_value)
    end)
  end

  defp transform_nested_objects(data, _version), do: data

  defp rename_field(data, old_key, new_key) when is_map(data) do
    case Map.pop(data, old_key) do
      {nil, data} -> data
      {value, data} -> Map.put(data, new_key, value)
    end
  end
end
