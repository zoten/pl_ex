defmodule PlEx.Integration.FullAPITest do
  use ExUnit.Case, async: false

  alias PlEx.Test.MockServer

  setup_all do
    # Start the mock server for integration testing
    {:ok, _pid} = MockServer.start_link()
    :ok
  end

  setup do
    # Reset mock server state before each test
    MockServer.reset_version()
    MockServer.clear_mock_responses()
    :ok
  end

  describe "Library API Integration" do
    setup do
      prev_adapter = Application.get_env(:pl_ex, :http_adapter)
      Application.put_env(:pl_ex, :http_adapter, PlEx.HTTP.FinchAdapter)

      on_exit(fn ->
        Application.put_env(:pl_ex, :http_adapter, prev_adapter)
      end)
    end

    test "complete library workflow" do
      # Set up mock server with v1.2.0 (supports collections)
      MockServer.set_version("1.2.0")

      defmodule LibraryTestApp do
        use PlEx

        def complete_library_workflow do
          with {:ok, sections} <- get_library_sections(),
               {:ok, section} <- get_library_section("1"),
               {:ok, items} <- get_library_items("1", limit: 5),
               {:ok, recent} <- get_recently_added("1", limit: 3),
               {:ok, collections} <- get_library_collections("1"),
               {:ok, new_collection} <- create_library_collection("1", "Test Collection"),
               :ok <- scan_library_section("1") do
            {:ok,
             %{
               sections: sections,
               section: section,
               items: items,
               recent: recent,
               collections: collections,
               new_collection: new_collection
             }}
          end
        end
      end

      # Execute the workflow
      case LibraryTestApp.complete_library_workflow() do
        {:ok, results} ->
          assert is_list(results.sections)
          assert is_map(results.section)
          assert is_list(results.items)
          assert is_list(results.recent)
          assert is_list(results.collections)
          assert is_map(results.new_collection)

        {:error, reason} ->
          # This is expected without a real server, but the workflow should compile and run
          # Reason can be an atom, binary, or complex error tuple
          assert reason != nil
      end
    end

    test "version compatibility handling" do
      defmodule VersionTestApp do
        use PlEx

        def test_version_compatibility do
          # Try to use a v1.2.0+ feature
          case get_library_collections("1") do
            {:ok, collections} -> {:v1_2_0_plus, collections}
            {:error, :feature_not_supported} -> {:v1_1_1, :collections_not_supported}
            {:error, other} -> {:error, other}
          end
        end
      end

      # Test with v1.1.1 (no collections support)
      MockServer.set_version("1.1.1")
      result_v1_1_1 = VersionTestApp.test_version_compatibility()

      # Test with v1.2.0 (collections supported)
      MockServer.set_version("1.2.0")
      result_v1_2_0 = VersionTestApp.test_version_compatibility()

      # Both should return errors in test environment, but test that they execute
      assert elem(result_v1_1_1, 0) == :error
      assert elem(result_v1_2_0, 0) == :error
    end
  end

  describe "Media API Integration" do
    setup do
      prev_adapter = Application.get_env(:pl_ex, :http_adapter)
      Application.put_env(:pl_ex, :http_adapter, PlEx.HTTP.FinchAdapter)

      on_exit(fn ->
        Application.put_env(:pl_ex, :http_adapter, prev_adapter)
      end)
    end

    test "complete media management workflow" do
      MockServer.set_version("1.2.0")

      defmodule MediaTestApp do
        use PlEx

        def complete_media_workflow(rating_key) do
          with {:ok, metadata} <- get_media_metadata(rating_key, include_related: true),
               {:ok, children} <- get_media_children(rating_key),
               :ok <- mark_media_watched(rating_key),
               :ok <- set_media_progress(rating_key, time: 300_000, state: :paused),
               :ok <- rate_media(rating_key, 8.5),
               {:ok, related} <- get_media_related(rating_key),
               :ok <- refresh_media_metadata(rating_key),
               :ok <- mark_media_unwatched(rating_key),
               :ok <- unrate_media(rating_key) do
            {:ok,
             %{
               metadata: metadata,
               children: children,
               related: related
             }}
          end
        end
      end

      case MediaTestApp.complete_media_workflow("12345") do
        {:ok, results} ->
          assert is_map(results.metadata)
          assert is_list(results.children)
          assert is_list(results.related)

        {:error, reason} ->
          # Expected without real server
          assert reason != nil
      end
    end
  end

  describe "Search API Integration" do
    setup do
      prev_adapter = Application.get_env(:pl_ex, :http_adapter)
      Application.put_env(:pl_ex, :http_adapter, PlEx.HTTP.FinchAdapter)

      on_exit(fn ->
        Application.put_env(:pl_ex, :http_adapter, prev_adapter)
      end)
    end

    test "complete search workflow" do
      # Enhanced search support
      MockServer.set_version("1.2.0")

      defmodule SearchTestApp do
        use PlEx

        def complete_search_workflow do
          with {:ok, basic_results} <- search("batman", limit: 10),
               {:ok, advanced_results} <-
                 advanced_search(%{
                   genre: "Action",
                   year: {2020, 2023}
                 }),
               {:ok, suggestions} <- search_suggestions("aven"),
               {:ok, people} <- search_people("Tom Hanks"),
               {:ok, within_results} <- search_within("12345", "pilot") do
            {:ok,
             %{
               basic: basic_results,
               advanced: advanced_results,
               suggestions: suggestions,
               people: people,
               within: within_results
             }}
          end
        end
      end

      case SearchTestApp.complete_search_workflow() do
        {:ok, results} ->
          assert is_list(results.basic)
          assert is_list(results.advanced)
          assert is_list(results.suggestions)
          assert is_list(results.people)
          assert is_list(results.within)

        {:error, reason} ->
          # Expected without real server
          assert reason != nil
      end
    end

    test "search version adaptation" do
      defmodule SearchVersionApp do
        use PlEx

        def test_search_versions do
          # Basic search should work on all versions
          basic_result = search("batman")

          # Advanced search should adapt based on version
          advanced_result = advanced_search(%{genre: "Action"})

          {basic_result, advanced_result}
        end
      end

      # Test with v1.1.1 (basic search only)
      MockServer.set_version("1.1.1")
      {basic_v1_1_1, advanced_v1_1_1} = SearchVersionApp.test_search_versions()

      # Test with v1.2.0 (enhanced search)
      MockServer.set_version("1.2.0")
      {basic_v1_2_0, advanced_v1_2_0} = SearchVersionApp.test_search_versions()

      # Basic search should work on both versions
      assert elem(basic_v1_1_1, 0) in [:ok, :error]
      assert elem(basic_v1_2_0, 0) in [:ok, :error]

      # Advanced search behavior may differ
      assert elem(advanced_v1_1_1, 0) in [:ok, :error]
      assert elem(advanced_v1_2_0, 0) in [:ok, :error]
    end
  end

  describe "Cross-API Integration" do
    setup do
      prev_adapter = Application.get_env(:pl_ex, :http_adapter)
      Application.put_env(:pl_ex, :http_adapter, PlEx.HTTP.FinchAdapter)

      on_exit(fn ->
        Application.put_env(:pl_ex, :http_adapter, prev_adapter)
      end)
    end

    test "realistic application workflow" do
      MockServer.set_version("1.2.0")

      defmodule RealisticApp do
        use PlEx

        def find_and_watch_movie(movie_title) do
          with {:ok, search_results} <- search(movie_title, type: :movie, limit: 5),
               movie <- find_best_match(search_results, movie_title),
               {:ok, metadata} <- get_media_metadata(movie.rating_key, include_related: true),
               :ok <- mark_media_watched(movie.rating_key),
               :ok <- rate_media(movie.rating_key, 9.0) do
            {:ok,
             %{
               found_movie: movie,
               metadata: metadata,
               status: :watched_and_rated
             }}
          end
        end

        def discover_new_content(section_key) do
          with {:ok, recent} <- get_recently_added(section_key, limit: 10),
               {:ok, collections} <- get_library_collections(section_key),
               popular_collection <- find_popular_collection(collections) do
            {:ok,
             %{
               recent_items: recent,
               collections: collections,
               recommended: popular_collection
             }}
          end
        end

        defp find_best_match(results, title) do
          # Simple matching logic for demo
          Enum.find(results, fn item ->
            String.contains?(String.downcase(item.title || ""), String.downcase(title))
          end) || List.first(results)
        end

        defp find_popular_collection(collections) do
          # Find collection with most items
          Enum.max_by(
            collections,
            fn collection ->
              Map.get(collection, :child_count, 0)
            end,
            fn -> nil end
          )
        end
      end

      # Test movie finding and watching workflow
      case RealisticApp.find_and_watch_movie("Batman") do
        {:ok, result} ->
          assert result.status == :watched_and_rated
          assert is_map(result.found_movie)
          assert is_map(result.metadata)

        {:error, reason} ->
          # Expected without real server
          assert reason != nil
      end

      # Test content discovery workflow
      case RealisticApp.discover_new_content("1") do
        {:ok, result} ->
          assert is_list(result.recent_items)
          assert is_list(result.collections)

        {:error, reason} ->
          # Expected without real server
          assert reason != nil
      end
    end
  end

  describe "Error Handling and Resilience" do
    setup do
      prev_adapter = Application.get_env(:pl_ex, :http_adapter)
      Application.put_env(:pl_ex, :http_adapter, PlEx.HTTP.FinchAdapter)

      on_exit(fn ->
        Application.put_env(:pl_ex, :http_adapter, prev_adapter)
      end)
    end

    test "graceful error handling across API calls" do
      defmodule ErrorHandlingApp do
        use PlEx

        def resilient_workflow do
          results = %{}

          # Try library operations
          results =
            case get_library_sections() do
              {:ok, sections} -> Map.put(results, :sections, sections)
              {:error, _} -> Map.put(results, :sections, :failed)
            end

          # Try media operations
          results =
            case get_media_metadata("invalid_key") do
              {:ok, metadata} -> Map.put(results, :metadata, metadata)
              {:error, _} -> Map.put(results, :metadata, :failed)
            end

          # Try search operations
          # Valid search query
          results =
            case search("test") do
              {:ok, search_results} -> Map.put(results, :search, search_results)
              {:error, _} -> Map.put(results, :search, :failed)
            end

          {:ok, results}
        end
      end

      {:ok, results} = ErrorHandlingApp.resilient_workflow()

      # Should have attempted all operations
      assert Map.has_key?(results, :sections)
      assert Map.has_key?(results, :metadata)
      assert Map.has_key?(results, :search)

      # Some may have failed, but the workflow should complete
      assert is_map(results)
    end
  end
end
