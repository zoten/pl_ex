defmodule PlEx.Version.Detector do
  @moduledoc """
  Automatic detection of Plex Media Server API version.

  Detects the API version from server responses and provides fallback
  mechanisms for version detection failures.
  """

  alias PlEx.{Transport, Error}

  @supported_versions ["1.1.1", "1.2.0", "1.3.0"]
  @default_version "1.1.1"

  # Version detection endpoints
  @root_endpoint "/"
  @identity_endpoint "/identity"

  @doc """
  Detects the API version of a Plex Media Server.

  ## Detection Strategy

  1. Check `X-Plex-Pms-Api-Version` header from root endpoint
  2. Fall back to identity endpoint if root fails
  3. Use feature probing as last resort
  4. Default to minimum supported version if all else fails

  ## Examples

      {:ok, "1.2.0"} = PlEx.Version.Detector.detect_server_version(connection)
      {:ok, "1.1.1"} = PlEx.Version.Detector.detect_server_version(connection, fallback: true)
  """
  @spec detect_server_version(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def detect_server_version(connection, opts \\ []) do
    fallback = Keyword.get(opts, :fallback, true)

    with {:error, _} <- detect_from_root(connection),
         {:error, _} <- detect_from_identity(connection),
         {:error, _} <- detect_from_features(connection) do
      if fallback do
        {:ok, @default_version}
      else
        {:error, Error.not_found(:version_detection_failed)}
      end
    end
  end

  @doc """
  Detects version from multiple connections and returns the best match.

  Useful when dealing with multiple server connections to find the
  highest common version supported.
  """
  @spec detect_from_connections([map()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def detect_from_connections(connections, opts \\ []) when is_list(connections) do
    versions =
      connections
      |> Enum.map(&detect_server_version(&1, opts))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, version} -> version end)

    case versions do
      [] -> {:error, Error.not_found(:no_versions_detected)}
      versions -> {:ok, find_common_version(versions)}
    end
  end

  @doc """
  Validates if a version string is supported by PlEx.
  """
  @spec supported_version?(String.t()) :: boolean()
  def supported_version?(version) when is_binary(version) do
    version in @supported_versions
  end

  @doc """
  Returns all supported API versions.
  """
  @spec supported_versions() :: [String.t()]
  def supported_versions, do: @supported_versions

  @doc """
  Returns the default fallback version.
  """
  @spec default_version() :: String.t()
  def default_version, do: @default_version

  # Private functions

  defp detect_from_root(connection) do
    case make_request(connection, @root_endpoint) do
      {:ok, _body, headers} ->
        extract_version_from_headers(headers)

      {:error, _reason} ->
        {:error, :root_endpoint_failed}
    end
  end

  defp detect_from_identity(connection) do
    case make_request(connection, @identity_endpoint) do
      {:ok, body, headers} ->
        case extract_version_from_headers(headers) do
          {:ok, version} -> {:ok, version}
          {:error, _} -> extract_version_from_body(body)
        end

      {:error, _reason} ->
        {:error, :identity_endpoint_failed}
    end
  end

  defp detect_from_features(connection) do
    # Feature probing as last resort
    features_to_check = [
      # Basic library support
      {"/library/sections", "1.1.1"},
      # Hub support indicates 1.2.0+
      {"/hubs", "1.2.0"},
      # Butler API indicates 1.3.0+
      {"/butler", "1.3.0"}
    ]

    probe_features(connection, features_to_check)
  end

  defp make_request(connection, path) do
    opts = [
      credentials_provider: {PlEx.Auth.LegacyToken, token: connection.access_token},
      accept: "application/json"
    ]

    case Transport.request(:pms, :get, path, opts) do
      {:ok, response} ->
        # Extract headers from response (implementation depends on HTTP adapter)
        headers = extract_headers_from_response(response)
        body = response
        {:ok, body, headers}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_version_from_headers(headers) when is_list(headers) do
    case find_header(headers, "x-plex-pms-api-version") do
      version when is_binary(version) and version != "" ->
        if supported_version?(version) do
          {:ok, version}
        else
          {:ok, find_closest_supported_version(version)}
        end

      _ ->
        {:error, :version_header_not_found}
    end
  end

  defp extract_version_from_body(body) when is_map(body) do
    # Try to extract version from response body
    version =
      body["version"] || body["Version"] ||
        get_in(body, ["MediaContainer", "version"]) ||
        get_in(body, ["MediaContainer", "Version"])

    case version do
      version when is_binary(version) ->
        if supported_version?(version) do
          {:ok, version}
        else
          {:ok, find_closest_supported_version(version)}
        end

      _ ->
        {:error, :version_not_in_body}
    end
  end

  defp extract_version_from_body(_body), do: {:error, :invalid_body_format}

  defp probe_features(connection, features) do
    Enum.reduce_while(features, {:error, :no_features_detected}, fn {endpoint, version}, _acc ->
      case make_request(connection, endpoint) do
        {:ok, _body, _headers} ->
          {:halt, {:ok, version}}

        {:error, _} ->
          {:cont, {:error, :feature_probe_failed}}
      end
    end)
  end

  defp find_header(headers, header_name) do
    normalized_name = String.downcase(header_name)

    Enum.find_value(headers, fn
      {name, value} when is_binary(name) and is_binary(value) ->
        if String.downcase(name) == normalized_name, do: value, else: nil

      _ ->
        nil
    end)
  end

  defp extract_headers_from_response(response) do
    # This is a simplified implementation
    # In reality, this would depend on the HTTP adapter response format
    case response do
      %{headers: headers} -> headers
      _ -> []
    end
  end

  defp find_closest_supported_version(version) do
    # Parse version and find the closest supported version
    case parse_version(version) do
      {:ok, {major, minor, patch}} ->
        @supported_versions
        |> Enum.map(&{&1, parse_version(&1)})
        |> Enum.filter(fn {_, parsed} -> match?({:ok, _}, parsed) end)
        |> Enum.map(fn {v, {:ok, parsed}} -> {v, parsed} end)
        |> Enum.min_by(fn {_, {maj, min, pat}} ->
          abs(major - maj) * 10_000 + abs(minor - min) * 100 + abs(patch - pat)
        end)
        |> elem(0)

      {:error, _} ->
        @default_version
    end
  end

  defp find_common_version(versions) do
    # Find the lowest version that's common across all detected versions
    versions
    |> Enum.map(&parse_version/1)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, parsed} -> parsed end)
    |> case do
      [] ->
        @default_version

      parsed_versions ->
        {min_major, min_minor, min_patch} =
          parsed_versions
          |> Enum.min_by(fn {maj, min, pat} -> maj * 10_000 + min * 100 + pat end)

        "#{min_major}.#{min_minor}.#{min_patch}"
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
end
