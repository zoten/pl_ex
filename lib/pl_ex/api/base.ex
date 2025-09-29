defmodule PlEx.API.Base do
  @moduledoc """
  Base module for PlEx API modules.

  Provides common functionality and patterns used across all API modules,
  including version-aware request handling, response adaptation, and error handling.
  """

  alias PlEx.{Transport, Version, Error, Schemas}

  @doc """
  Makes a version-aware API request.

  This function handles version detection, request adaptation, and response normalization
  automatically based on the target API version.
  """
  @spec request(atom(), Transport.method(), String.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def request(target, method, path, opts \\ []) do
    with {:ok, version} <- get_or_detect_version(opts),
         {:ok, adapted_path} <- Version.Adapter.adapt_endpoint(path, version),
         {:ok, adapted_params} <-
           Version.Adapter.adapt_params(opts[:params] || %{}, path, version) do
      request_opts =
        opts
        |> Keyword.put(:params, adapted_params)
        |> add_version_context(version)

      case Transport.request(target, method, adapted_path, request_opts) do
        {:ok, response} ->
          adapt_response(response, opts[:response_schema], version)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Makes a request and adapts the response to a specific schema.

  Useful when you know the expected response schema and want automatic adaptation.
  """
  @spec request_with_schema(atom(), Transport.method(), String.t(), module(), keyword()) ::
          {:ok, struct() | [struct()]} | {:error, term()}
  def request_with_schema(target, method, path, schema_module, opts \\ []) do
    opts_with_schema = Keyword.put(opts, :response_schema, schema_module)
    request(target, method, path, opts_with_schema)
  end

  @doc """
  Makes a paginated request, handling pagination automatically.

  Returns all results by following pagination links until all data is retrieved.
  """
  @spec paginated_request(atom(), Transport.method(), String.t(), keyword()) ::
          {:ok, [term()]} | {:error, term()}
  def paginated_request(target, method, path, opts \\ []) do
    initial_params = opts[:params] || %{}
    collect_paginated_results(target, method, path, opts, initial_params, [])
  end

  @doc """
  Validates that a feature is supported in the current version.

  Returns an error if the feature is not available, otherwise proceeds with the operation.
  """
  @spec require_feature(atom(), keyword()) :: :ok | {:error, term()}
  def require_feature(feature, opts) do
    case get_or_detect_version(opts) do
      {:ok, version} ->
        check_feature_support(feature, version, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_feature_support(feature, version, opts) do
    if Version.Compatibility.supports_version?(version, feature) do
      :ok
    else
      handle_unsupported_feature(feature, version, opts)
    end
  end

  defp handle_unsupported_feature(feature, version, opts) do
    case Version.Compatibility.suggest_alternative(build_connection(opts), feature) do
      :supported ->
        :ok

      {:upgrade_required, required_version} ->
        {:error,
         Error.config_error(:feature_requires_upgrade, %{
           feature: feature,
           current_version: version,
           required_version: required_version
         })}

      {:alternative, suggestion} ->
        {:error,
         Error.config_error(:feature_not_supported, %{
           feature: feature,
           version: version,
           suggestion: suggestion
         })}
    end
  end

  @doc """
  Checks if an endpoint is available in the current version.

  Provides warnings for deprecated endpoints and suggests alternatives.
  """
  @spec check_endpoint_availability(String.t(), keyword()) ::
          :ok | {:warning, term()} | {:error, term()}
  def check_endpoint_availability(path, opts) do
    case get_or_detect_version(opts) do
      {:ok, version} ->
        case Version.Adapter.endpoint_deprecation_info(path, version) do
          :not_deprecated ->
            :ok

          {:deprecated, info} ->
            {:warning,
             Error.config_error(:endpoint_deprecated, %{
               endpoint: path,
               deprecation_info: info
             })}

          {:removed, info} ->
            {:error,
             Error.config_error(:endpoint_removed, %{
               endpoint: path,
               removal_info: info
             })}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Builds standard query parameters for list endpoints.

  Handles common parameters like pagination, sorting, and filtering
  with version-specific adaptations.
  """
  @spec build_list_params(keyword()) :: map()
  def build_list_params(opts) do
    base_params = %{}

    base_params
    |> add_pagination_params(opts)
    |> add_sorting_params(opts)
    |> add_filtering_params(opts)
  end

  # Private functions

  defp get_or_detect_version(opts) do
    case Keyword.get(opts, :version) do
      version when is_binary(version) -> {:ok, version}
      nil -> detect_version_from_connection(opts)
    end
  end

  defp detect_version_from_connection(opts) do
    case build_connection(opts) do
      %{version: version} when is_binary(version) -> {:ok, version}
      connection -> Version.Detector.detect_server_version(connection)
    end
  end

  defp build_connection(opts) do
    # Build a connection map from options
    # This would typically come from the credentials provider
    case Keyword.get(opts, :connection) do
      connection when is_map(connection) -> connection
      nil -> %{version: Version.Detector.default_version()}
    end
  end

  defp add_version_context(opts, version) do
    opts
    |> Keyword.put(:api_version, version)
    |> Keyword.update(:headers, [], fn headers ->
      [{"X-Plex-Api-Version", version} | headers]
    end)
  end

  defp adapt_response(response, nil, _version) do
    # No schema specified, return raw response
    {:ok, response}
  end

  defp adapt_response(response, schema_module, version) when is_atom(schema_module) do
    case response do
      %{"MediaContainer" => _container} ->
        # Handle MediaContainer responses
        Schemas.Adapter.adapt_media_container(response, schema_module, version)

      %{} = single_item ->
        # Handle single item responses
        Schemas.Adapter.adapt_response(single_item, schema_module, version)

      items when is_list(items) ->
        # Handle list responses
        Schemas.Adapter.adapt_response_list(items, schema_module, version)

      other ->
        {:ok, other}
    end
  end

  defp collect_paginated_results(target, method, path, opts, params, acc) do
    current_params = Map.merge(opts[:params] || %{}, params)
    request_opts = Keyword.put(opts, :params, current_params)

    case request(target, method, path, request_opts) do
      {:ok, %{"MediaContainer" => container}} ->
        items = extract_items_from_container(container)
        # ✅ O(1) prepend instead of O(n) append
        new_acc = [items | acc]

        case get_next_page_params(container, current_params) do
          {:ok, next_params} ->
            collect_paginated_results(target, method, path, opts, next_params, new_acc)

          :no_more_pages ->
            # Flatten and reverse once at the end - O(n) total
            {:ok, new_acc |> Enum.reverse() |> List.flatten()}
        end

      {:ok, items} when is_list(items) ->
        {:ok, (acc |> Enum.reverse() |> List.flatten()) ++ items}

      {:ok, single_item} ->
        {:ok, (acc |> Enum.reverse() |> List.flatten()) ++ [single_item]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_items_from_container(container) do
    # Extract items from MediaContainer, trying different possible keys
    item_keys = ["Directory", "Metadata", "Video", "Track", "Photo", "Hub", "Playlist"]

    Enum.find_value(item_keys, [], fn key ->
      case Map.get(container, key) do
        items when is_list(items) -> items
        single_item when is_map(single_item) -> [single_item]
        nil -> nil
      end
    end)
  end

  defp get_next_page_params(container, current_params) do
    size = Map.get(container, "size", 0)
    total_size = Map.get(container, "totalSize")
    offset = Map.get(current_params, "X-Plex-Container-Start", 0)

    case {size, total_size} do
      {size, total} when is_integer(total) and offset + size < total ->
        next_offset = offset + size
        {:ok, Map.put(current_params, "X-Plex-Container-Start", next_offset)}

      _ ->
        :no_more_pages
    end
  end

  defp add_pagination_params(params, opts) do
    params
    |> maybe_add_param("X-Plex-Container-Start", opts[:offset])
    |> maybe_add_param("X-Plex-Container-Size", opts[:limit])
  end

  defp add_sorting_params(params, opts) do
    case opts[:sort] do
      {field, :asc} -> Map.put(params, "sort", "#{field}:asc")
      {field, :desc} -> Map.put(params, "sort", "#{field}:desc")
      field when is_atom(field) -> Map.put(params, "sort", to_string(field))
      _ -> params
    end
  end

  defp add_filtering_params(params, opts) do
    case opts[:filters] do
      filters when is_map(filters) ->
        Enum.reduce(filters, params, fn {key, value}, acc ->
          Map.put(acc, to_string(key), to_string(value))
        end)

      _ ->
        params
    end
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Map.put(params, key, value)
end
