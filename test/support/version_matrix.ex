defmodule PlEx.Test.VersionMatrix do
  @moduledoc """
  Version matrix testing framework for PlEx.

  Provides macros and utilities to automatically test functionality
  across all supported Plex API versions, ensuring compatibility
  and catching version-specific regressions.
  """

  @supported_versions ["1.1.1", "1.2.0", "1.3.0"]

  @doc """
  Macro to generate tests across all supported versions.

  ## Usage

      defmodule PlEx.LibraryTest do
        use PlEx.Test.VersionMatrix

        test_across_versions "gets library sections" do
          {:ok, sections} = PlEx.API.Library.get_sections()
          assert is_list(sections)
        end
      end

  This will generate separate test cases for each supported version.
  """
  defmacro test_across_versions(description, do: block) do
    for version <- @supported_versions do
      test_name = "#{description} (v#{version})"

      quote do
        test unquote(test_name) do
          PlEx.Test.MockServer.set_version(unquote(version))

          try do
            unquote(block)
          after
            PlEx.Test.MockServer.reset_version()
          end
        end
      end
    end
  end

  @doc """
  Macro to generate tests for specific version ranges.

  ## Usage

      test_for_versions "collections API", versions: ["1.2.0", "1.3.0"] do
        {:ok, collections} = PlEx.API.Collections.list()
        assert is_list(collections)
      end
  """
  defmacro test_for_versions(description, opts, do: block) do
    versions = Keyword.get(opts, :versions, @supported_versions)

    for version <- versions do
      test_name = "#{description} (v#{version})"

      quote do
        test unquote(test_name) do
          PlEx.Test.MockServer.set_version(unquote(version))

          try do
            unquote(block)
          after
            PlEx.Test.MockServer.reset_version()
          end
        end
      end
    end
  end

  @doc """
  Macro to test version-specific features with graceful degradation.

  ## Usage

      test_with_fallback "collections or playlists",
        feature: :collections,
        fallback: :playlists do

        case PlEx.Version.supports?(connection, :collections) do
          true -> test_collections()
          false -> test_playlists()
        end
      end
  """
  defmacro test_with_fallback(description, opts, do: block) do
    feature = Keyword.get(opts, :feature)
    fallback = Keyword.get(opts, :fallback)

    for version <- @supported_versions do
      test_name = "#{description} (v#{version})"

      quote do
        test unquote(test_name) do
          PlEx.Test.MockServer.set_version(unquote(version))

          try do
            # Set up feature availability context
            connection = PlEx.Test.MockServer.get_connection()
            supports_feature = PlEx.Version.Compatibility.supports?(connection, unquote(feature))

            supports_fallback =
              PlEx.Version.Compatibility.supports?(connection, unquote(fallback))

            # Make feature support available in test context
            var!(feature_supported) = supports_feature
            var!(fallback_supported) = supports_fallback
            var!(connection) = connection

            unquote(block)
          after
            PlEx.Test.MockServer.reset_version()
          end
        end
      end
    end
  end

  @doc """
  Runs a test function with a specific version context.

  ## Usage

      PlEx.Test.VersionMatrix.with_version("1.2.0", fn ->
        # Test code here runs with v1.2.0 context
      end)
  """
  def with_version(version, test_fn) when is_binary(version) and is_function(test_fn, 0) do
    if version in @supported_versions do
      PlEx.Test.MockServer.set_version(version)

      try do
        test_fn.()
      after
        PlEx.Test.MockServer.reset_version()
      end
    else
      raise ArgumentError,
            "Unsupported version: #{version}. Supported: #{inspect(@supported_versions)}"
    end
  end

  @doc """
  Generates compatibility matrix data for analysis.

  Returns a map showing which features are available in which versions.
  """
  def generate_compatibility_matrix do
    features = [
      :library_sections,
      :media_metadata,
      :basic_search,
      :playlists,
      :collections,
      :hubs,
      :enhanced_search,
      :webhooks_v2,
      :smart_collections,
      :advanced_hubs,
      :activity_monitoring
    ]

    matrix =
      for version <- @supported_versions, into: %{} do
        version_features =
          for feature <- features, into: %{} do
            {feature, PlEx.Version.Compatibility.supports_version?(version, feature)}
          end

        {version, version_features}
      end

    %{
      versions: @supported_versions,
      features: features,
      matrix: matrix,
      generated_at: DateTime.utc_now()
    }
  end

  @doc """
  Validates that all version matrix tests are properly configured.

  Checks for common issues like missing mock responses or
  inconsistent test expectations across versions.
  """
  def validate_test_matrix(module) when is_atom(module) do
    issues = []

    # Check if module uses version matrix
    issues =
      if has_version_matrix_tests?(module) do
        issues
      else
        ["Module #{module} does not use version matrix testing" | issues]
      end

    # Check for version-specific mock data
    issues =
      for version <- @supported_versions, reduce: issues do
        acc ->
          if PlEx.Test.MockServer.has_mock_data_for_version?(version) do
            acc
          else
            ["Missing mock data for version #{version}" | acc]
          end
      end

    case issues do
      [] -> :ok
      issues -> {:error, issues}
    end
  end

  @doc """
  Returns statistics about version matrix test coverage.
  """
  def test_coverage_stats(module) when is_atom(module) do
    test_functions = get_test_functions(module)
    version_matrix_tests = get_version_matrix_tests(module)

    %{
      total_tests: length(test_functions),
      version_matrix_tests: length(version_matrix_tests),
      coverage_percentage: calculate_coverage_percentage(test_functions, version_matrix_tests),
      versions_covered: @supported_versions,
      missing_coverage: find_missing_coverage(module)
    }
  end

  # Helper functions for the macros

  defp has_version_matrix_tests?(module) do
    module.__info__(:functions)
    |> Enum.any?(fn {name, _arity} ->
      String.contains?(to_string(name), "(v")
    end)
  end

  defp get_test_functions(module) do
    module.__info__(:functions)
    |> Enum.filter(fn {name, arity} ->
      String.starts_with?(to_string(name), "test ") and arity == 1
    end)
  end

  defp get_version_matrix_tests(module) do
    module.__info__(:functions)
    |> Enum.filter(fn {name, _arity} ->
      name_str = to_string(name)
      String.starts_with?(name_str, "test ") and String.contains?(name_str, "(v")
    end)
  end

  defp calculate_coverage_percentage(all_tests, matrix_tests) do
    if Enum.empty?(all_tests) do
      0.0
    else
      Enum.count(matrix_tests) / Enum.count(all_tests) * 100
    end
  end

  defp find_missing_coverage(module) do
    # Analyze which API areas might be missing version matrix coverage
    # This is a simplified implementation
    test_names =
      get_test_functions(module)
      |> Enum.map(fn {name, _} -> to_string(name) end)

    api_areas = ["library", "media", "search", "collections", "hubs", "playlists"]

    Enum.filter(api_areas, fn area ->
      not Enum.any?(test_names, fn name ->
        String.contains?(String.downcase(name), area) and String.contains?(name, "(v")
      end)
    end)
  end

  # Import this module to get the macros
  defmacro __using__(_opts) do
    quote do
      import PlEx.Test.VersionMatrix

      # Set up test environment
      setup do
        # Ensure clean state for each test
        PlEx.Test.MockServer.reset_version()
        :ok
      end
    end
  end
end
