defmodule PlEx.Version.Compatibility do
  @moduledoc """
  Feature compatibility checks for different Plex API versions.

  This module provides a feature-based approach to version compatibility,
  allowing code to check for specific capabilities rather than exact versions.
  """

  @type feature :: atom()
  @type version :: String.t()
  @type connection :: map()

  # Feature compatibility matrix
  @feature_matrix %{
    # Core features (available in all supported versions)
    library_sections: "1.1.1",
    media_metadata: "1.1.1",
    basic_search: "1.1.1",
    playlists: "1.1.1",

    # v1.2.0+ features
    collections: "1.2.0",
    hubs: "1.2.0",
    enhanced_search: "1.2.0",
    webhooks_v2: "1.2.0",
    butler_tasks: "1.2.0",

    # v1.3.0+ features
    smart_collections: "1.3.0",
    advanced_hubs: "1.3.0",
    enhanced_butler: "1.3.0",
    activity_monitoring: "1.3.0",

    # Experimental features (may not be stable)
    experimental_api: "1.4.0"
  }

  # Deprecated features and their replacement suggestions
  @deprecated_features %{
    library_on_deck: %{
      deprecated_in: "1.2.0",
      replacement: :hubs,
      endpoint_change: {"/library/onDeck", "/hubs/home/onDeck"}
    },
    old_search_api: %{
      deprecated_in: "1.2.0",
      replacement: :enhanced_search,
      endpoint_change: {"/search", "/hubs/search"}
    }
  }

  @doc """
  Checks if a connection supports a specific feature.

  ## Examples

      PlEx.Version.Compatibility.supports?(connection, :collections)
      # => true (if server is v1.2.0+)
      
      PlEx.Version.Compatibility.supports?(connection, :smart_collections)
      # => false (if server is v1.1.1)
  """
  @spec supports?(connection(), feature()) :: boolean()
  def supports?(connection, feature) when is_atom(feature) do
    case get_connection_version(connection) do
      {:ok, version} -> supports_version?(version, feature)
      {:error, _} -> false
    end
  end

  @doc """
  Checks if a specific version supports a feature.

  ## Examples

      PlEx.Version.Compatibility.supports_version?("1.2.0", :collections)
      # => true
      
      PlEx.Version.Compatibility.supports_version?("1.1.1", :collections)  
      # => false
  """
  @spec supports_version?(version(), feature()) :: boolean()
  def supports_version?(version, feature) when is_binary(version) and is_atom(feature) do
    case Map.get(@feature_matrix, feature) do
      nil -> false
      required_version -> version_gte?(version, required_version)
    end
  end

  @doc """
  Returns all features supported by a connection.

  ## Examples

      PlEx.Version.Compatibility.supported_features(connection)
      # => [:library_sections, :media_metadata, :collections, :hubs, ...]
  """
  @spec supported_features(connection()) :: [feature()]
  def supported_features(connection) do
    case get_connection_version(connection) do
      {:ok, version} -> supported_features_for_version(version)
      {:error, _} -> []
    end
  end

  @doc """
  Returns all features supported by a specific version.
  """
  @spec supported_features_for_version(version()) :: [feature()]
  def supported_features_for_version(version) when is_binary(version) do
    @feature_matrix
    |> Enum.filter(fn {_feature, required_version} ->
      version_gte?(version, required_version)
    end)
    |> Enum.map(fn {feature, _} -> feature end)
  end

  @doc """
  Checks if a feature is deprecated in the given version.

  ## Examples

      PlEx.Version.Compatibility.deprecated?(connection, :library_on_deck)
      # => {:deprecated, %{replacement: :hubs, ...}} (if v1.2.0+)
      
      PlEx.Version.Compatibility.deprecated?(connection, :collections)
      # => false
  """
  @spec deprecated?(connection(), feature()) :: false | {:deprecated, map()}
  def deprecated?(connection, feature) when is_atom(feature) do
    case get_connection_version(connection) do
      {:ok, version} -> deprecated_in_version?(version, feature)
      {:error, _} -> false
    end
  end

  @doc """
  Checks if a feature is deprecated in a specific version.
  """
  @spec deprecated_in_version?(version(), feature()) :: false | {:deprecated, map()}
  def deprecated_in_version?(version, feature) when is_binary(version) and is_atom(feature) do
    case Map.get(@deprecated_features, feature) do
      nil ->
        false

      %{deprecated_in: deprecated_version} = info ->
        if version_gte?(version, deprecated_version) do
          {:deprecated, info}
        else
          false
        end
    end
  end

  @doc """
  Returns the minimum version required for a feature.

  ## Examples

      PlEx.Version.Compatibility.required_version(:collections)
      # => {:ok, "1.2.0"}
      
      PlEx.Version.Compatibility.required_version(:unknown_feature)
      # => {:error, :feature_not_found}
  """
  @spec required_version(feature()) :: {:ok, version()} | {:error, :feature_not_found}
  def required_version(feature) when is_atom(feature) do
    case Map.get(@feature_matrix, feature) do
      nil -> {:error, :feature_not_found}
      version -> {:ok, version}
    end
  end

  @doc """
  Returns a compatibility report for a connection.

  Provides a comprehensive overview of supported features, deprecated features,
  and upgrade recommendations.
  """
  @spec compatibility_report(connection()) :: map()
  def compatibility_report(connection) do
    case get_connection_version(connection) do
      {:ok, version} ->
        supported = supported_features_for_version(version)
        deprecated = find_deprecated_features(version)
        missing = find_missing_features(version)

        %{
          version: version,
          supported_features: supported,
          deprecated_features: deprecated,
          missing_features: missing,
          upgrade_recommendations: generate_upgrade_recommendations(version, missing)
        }

      {:error, reason} ->
        %{
          error: reason,
          version: nil,
          supported_features: [],
          deprecated_features: [],
          missing_features: [],
          upgrade_recommendations: []
        }
    end
  end

  @doc """
  Suggests alternative approaches when a feature is not supported.

  ## Examples

      PlEx.Version.Compatibility.suggest_alternative(connection, :collections)
      # => {:alternative, "Use playlists for grouping content"} (if v1.1.1)
      
      PlEx.Version.Compatibility.suggest_alternative(connection, :collections)  
      # => :supported (if v1.2.0+)
  """
  @spec suggest_alternative(connection(), feature()) ::
          :supported | {:alternative, String.t()} | {:upgrade_required, version()}
  def suggest_alternative(connection, feature) when is_atom(feature) do
    case supports?(connection, feature) do
      true ->
        :supported

      false ->
        suggest_alternative_for_unsupported_feature(connection, feature)
    end
  end

  # Private functions

  defp suggest_alternative_for_unsupported_feature(connection, feature) do
    case required_version(feature) do
      {:ok, required_version} ->
        suggest_based_on_version_comparison(connection, feature, required_version)

      {:error, :feature_not_found} ->
        {:alternative, "Feature not available in any supported version"}
    end
  end

  defp suggest_based_on_version_comparison(connection, feature, required_version) do
    case get_connection_version(connection) do
      {:ok, current_version} ->
        maybe_suggest_upgrade_or_alternative(current_version, required_version, feature)

      {:error, _} ->
        {:upgrade_required, required_version}
    end
  end

  defp maybe_suggest_upgrade_or_alternative(current_version, required_version, feature) do
    if version_lt?(current_version, required_version) do
      {:upgrade_required, required_version}
    else
      {:alternative, get_alternative_suggestion(feature)}
    end
  end

  defp get_connection_version(connection) do
    # Try to get version from connection metadata
    case connection do
      %{version: version} when is_binary(version) -> {:ok, version}
      %{server: %{"version" => version}} when is_binary(version) -> {:ok, version}
      _ -> PlEx.Version.Detector.detect_server_version(connection)
    end
  end

  defp version_gte?(version1, version2) do
    case {parse_version(version1), parse_version(version2)} do
      {{:ok, v1}, {:ok, v2}} -> compare_versions(v1, v2) >= 0
      _ -> false
    end
  end

  defp version_lt?(version1, version2) do
    case {parse_version(version1), parse_version(version2)} do
      {{:ok, v1}, {:ok, v2}} -> compare_versions(v1, v2) < 0
      _ -> false
    end
  end

  defp parse_version(version) when is_binary(version) do
    case String.split(version, ".") do
      [major, minor, patch] ->
        with {maj, ""} <- Integer.parse(major),
             {min, ""} <- Integer.parse(minor),
             {pat, ""} <- Integer.parse(patch) do
          {:ok, {maj, min, pat}}
        else
          _ -> {:error, :invalid_version_format}
        end

      _ ->
        {:error, :invalid_version_format}
    end
  end

  defp compare_versions({maj1, min1, pat1}, {maj2, min2, pat2}) do
    cond do
      maj1 != maj2 -> maj1 - maj2
      min1 != min2 -> min1 - min2
      true -> pat1 - pat2
    end
  end

  defp find_deprecated_features(version) do
    @deprecated_features
    |> Enum.filter(fn {_feature, %{deprecated_in: deprecated_version}} ->
      version_gte?(version, deprecated_version)
    end)
    |> Enum.map(fn {feature, _info} -> feature end)
  end

  defp find_missing_features(version) do
    @feature_matrix
    |> Enum.reject(fn {_feature, required_version} ->
      version_gte?(version, required_version)
    end)
    |> Enum.map(fn {feature, required_version} -> {feature, required_version} end)
  end

  defp generate_upgrade_recommendations(current_version, missing_features) do
    missing_features
    |> Enum.group_by(fn {_feature, required_version} -> required_version end)
    |> Enum.map(fn {target_version, features} ->
      feature_names = Enum.map(features, fn {feature, _} -> feature end)

      %{
        target_version: target_version,
        current_version: current_version,
        new_features: feature_names,
        priority: calculate_upgrade_priority(feature_names)
      }
    end)
    |> Enum.sort_by(& &1.priority, :desc)
  end

  defp calculate_upgrade_priority(features) do
    # Simple priority calculation based on feature importance
    high_priority_features = [:collections, :hubs, :enhanced_search]

    Enum.count(features, fn feature -> feature in high_priority_features end)
  end

  defp get_alternative_suggestion(feature) do
    case feature do
      :collections -> "Use playlists to group related content"
      :hubs -> "Use library sections and manual browsing"
      :smart_collections -> "Use regular collections with manual curation"
      :enhanced_search -> "Use basic search with additional filtering"
      :webhooks_v2 -> "Use polling or basic webhook functionality"
      _ -> "Feature not available, consider upgrading server"
    end
  end
end
