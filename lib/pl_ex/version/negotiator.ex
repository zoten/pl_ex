defmodule PlEx.Version.Negotiator do
  @moduledoc """
  Version negotiation and selection logic for PlEx.

  Handles the complex task of choosing the best API version to use
  based on server capabilities, client requirements, and compatibility constraints.
  """

  alias PlEx.{Error, Version}

  @type version :: String.t()
  @type negotiation_strategy :: :conservative | :aggressive | :exact | :latest
  @type negotiation_result :: {:ok, version()} | {:error, term()}

  @supported_versions ["1.1.1", "1.2.0", "1.3.0"]

  @doc """
  Negotiates the best API version to use.

  ## Strategies

  - `:conservative` - Choose the lowest common version (safest)
  - `:aggressive` - Choose the highest available version (most features)  
  - `:exact` - Require exact version match
  - `:latest` - Always use the latest supported version

  ## Examples

      # Conservative approach (default)
      {:ok, "1.1.1"} = PlEx.Version.Negotiator.negotiate(
        detected: "1.2.0", 
        requested: "1.1.1"
      )
      
      # Aggressive approach
      {:ok, "1.2.0"} = PlEx.Version.Negotiator.negotiate(
        detected: "1.2.0",
        requested: "1.1.1", 
        strategy: :aggressive
      )
  """
  @spec negotiate(keyword()) :: negotiation_result()
  def negotiate(opts) do
    detected = Keyword.get(opts, :detected)
    requested = Keyword.get(opts, :requested, :latest)
    strategy = Keyword.get(opts, :strategy, :conservative)

    case validate_inputs(detected, requested) do
      :ok -> do_negotiate(detected, requested, strategy)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Negotiates version for multiple server connections.

  Finds the best common version that works across all provided connections.
  """
  @spec negotiate_multi(keyword()) :: negotiation_result()
  def negotiate_multi(opts) do
    connections = Keyword.get(opts, :connections, [])
    requested = Keyword.get(opts, :requested, :latest)
    strategy = Keyword.get(opts, :strategy, :conservative)

    case detect_versions_from_connections(connections) do
      {:ok, versions} -> negotiate_from_versions(versions, requested, strategy)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks if a version negotiation would be successful.

  Useful for pre-flight checks before attempting operations.
  """
  @spec can_negotiate?(keyword()) :: boolean()
  def can_negotiate?(opts) do
    case negotiate(opts) do
      {:ok, _version} -> true
      {:error, _reason} -> false
    end
  end

  @doc """
  Returns the negotiation result with detailed information.

  Provides additional context about why a particular version was chosen.
  """
  @spec negotiate_with_info(keyword()) :: {:ok, map()} | {:error, term()}
  def negotiate_with_info(opts) do
    detected = Keyword.get(opts, :detected)
    requested = Keyword.get(opts, :requested, :latest)
    strategy = Keyword.get(opts, :strategy, :conservative)

    case negotiate(opts) do
      {:ok, chosen_version} ->
        info = %{
          chosen_version: chosen_version,
          detected_version: detected,
          requested_version: requested,
          strategy: strategy,
          reasoning: explain_choice(detected, requested, chosen_version, strategy),
          compatibility: Version.Compatibility.supported_features_for_version(chosen_version),
          limitations: find_limitations(detected, chosen_version)
        }

        {:ok, info}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Suggests the optimal negotiation strategy for given constraints.

  Analyzes the situation and recommends the best strategy to use.
  """
  @spec suggest_strategy(keyword()) :: negotiation_strategy()
  def suggest_strategy(opts) do
    detected = Keyword.get(opts, :detected)
    requested = Keyword.get(opts, :requested, :latest)
    features_needed = Keyword.get(opts, :features, [])

    cond do
      # If specific features are needed, be aggressive
      length(features_needed) > 0 ->
        if all_features_available?(detected, features_needed) do
          :aggressive
        else
          :conservative
        end

      # If exact version specified, use exact matching
      is_binary(requested) and requested != :latest ->
        :exact

      # Default to conservative for stability
      true ->
        :conservative
    end
  end

  # Private functions

  defp validate_inputs(detected, requested) do
    cond do
      not is_binary(detected) ->
        {:error, Error.config_error(:invalid_detected_version)}

      not (is_binary(requested) or requested in [:latest, :auto]) ->
        {:error, Error.config_error(:invalid_requested_version)}

      not version_supported?(detected) ->
        {:error, Error.config_error(:unsupported_detected_version, %{version: detected})}

      is_binary(requested) and not version_supported?(requested) ->
        {:error, Error.config_error(:unsupported_requested_version, %{version: requested})}

      true ->
        :ok
    end
  end

  defp do_negotiate(detected, requested, strategy) do
    case {normalize_requested(requested), strategy} do
      {requested_version, :exact} ->
        negotiate_exact(detected, requested_version)

      {requested_version, :conservative} ->
        negotiate_conservative(detected, requested_version)

      {requested_version, :aggressive} ->
        negotiate_aggressive(detected, requested_version)

      {_requested_version, :latest} ->
        negotiate_latest(detected)
    end
  end

  defp normalize_requested(:latest), do: List.last(@supported_versions)
  defp normalize_requested(:auto), do: :auto
  defp normalize_requested(version) when is_binary(version), do: version

  defp negotiate_exact(detected, requested) do
    if detected == requested do
      {:ok, detected}
    else
      {:error,
       Error.config_error(:version_mismatch, %{
         detected: detected,
         requested: requested
       })}
    end
  end

  defp negotiate_conservative(detected, requested) do
    case compare_versions(detected, requested) do
      # Use lower version (detected)
      :lt -> {:ok, detected}
      # Same version
      :eq -> {:ok, detected}
      # Use lower version (requested)
      :gt -> {:ok, requested}
    end
  end

  defp negotiate_aggressive(detected, requested) do
    case compare_versions(detected, requested) do
      # Use higher version (requested)
      :lt -> {:ok, requested}
      # Same version
      :eq -> {:ok, detected}
      # Use higher version (detected)
      :gt -> {:ok, detected}
    end
  end

  defp negotiate_latest(detected) do
    latest = List.last(@supported_versions)

    case compare_versions(detected, latest) do
      # Server doesn't support latest
      :lt -> {:ok, detected}
      # Use latest available
      _ -> {:ok, latest}
    end
  end

  defp detect_versions_from_connections(connections) do
    versions =
      connections
      |> Enum.map(&Version.Detector.detect_server_version/1)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, version} -> version end)

    case versions do
      [] -> {:error, Error.not_found(:no_versions_detected)}
      versions -> {:ok, versions}
    end
  end

  defp negotiate_from_versions(versions, requested, strategy) do
    case strategy do
      :conservative ->
        # Find lowest common version
        lowest = Enum.min_by(versions, &version_to_tuple/1)
        {:ok, lowest}

      :aggressive ->
        # Find highest common version
        highest = Enum.max_by(versions, &version_to_tuple/1)
        {:ok, highest}

      :exact ->
        requested_version = normalize_requested(requested)

        if requested_version in versions do
          {:ok, requested_version}
        else
          {:error, Error.config_error(:version_not_available_on_all_servers)}
        end

      :latest ->
        find_latest_common_version(versions)
    end
  end

  defp find_latest_common_version(versions) do
    # Use latest that's available on all servers
    latest_available =
      @supported_versions
      |> Enum.reverse()
      |> Enum.find(fn version ->
        Enum.all?(versions, fn v -> version_gte?(v, version) end)
      end)

    case latest_available do
      nil -> {:error, Error.config_error(:no_common_version)}
      version -> {:ok, version}
    end
  end

  defp compare_versions(v1, v2) do
    case {version_to_tuple(v1), version_to_tuple(v2)} do
      {t1, t2} when t1 < t2 -> :lt
      {t1, t2} when t1 > t2 -> :gt
      {t1, t1} -> :eq
    end
  end

  defp version_to_tuple(version) do
    case String.split(version, ".") do
      [major, minor, patch] ->
        {String.to_integer(major), String.to_integer(minor), String.to_integer(patch)}

      _ ->
        {0, 0, 0}
    end
  end

  defp version_gte?(v1, v2) do
    version_to_tuple(v1) >= version_to_tuple(v2)
  end

  defp version_supported?(version) do
    version in @supported_versions
  end

  defp explain_choice(_detected, _requested, chosen, strategy) do
    case strategy do
      :conservative ->
        "Chose #{chosen} using conservative strategy to ensure maximum compatibility"

      :aggressive ->
        "Chose #{chosen} using aggressive strategy to maximize available features"

      :exact ->
        "Chose #{chosen} to match exact version requirement"

      :latest ->
        "Chose #{chosen} as the latest version supported by the server"
    end
  end

  defp find_limitations(detected, chosen) do
    if detected != chosen do
      case compare_versions(detected, chosen) do
        :gt ->
          missing_features =
            Version.Compatibility.supported_features_for_version(detected) --
              Version.Compatibility.supported_features_for_version(chosen)

          [
            "Server supports #{detected} but using #{chosen}",
            "Missing features: #{inspect(missing_features)}"
          ]

        _ ->
          []
      end
    else
      []
    end
  end

  defp all_features_available?(version, features) do
    Enum.all?(features, fn feature ->
      Version.Compatibility.supports_version?(version, feature)
    end)
  end
end
