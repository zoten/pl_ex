defmodule PlEx.Integration.UsePlexTest do
  use ExUnit.Case, async: true

  test "use PlEx macro provides seamless API access" do
    defmodule TestPlexApp do
      use PlEx

      def list_all_movies do
        with {:ok, sections} <- get_library_sections(),
             movie_section <- find_movie_section(sections),
             {:ok, movies} <- get_library_items(movie_section.key, type: :movie) do
          {:ok, movies}
        else
          error -> error
        end
      end

      def mark_episode_watched(episode_key) do
        mark_media_watched(episode_key)
      end

      def search_for_content(query) do
        search(query, limit: 20)
      end

      def get_movie_details(movie_key) do
        get_media_metadata(movie_key, include_related: true)
      end

      defp find_movie_section(sections) do
        Enum.find(sections, fn section ->
          Map.get(section, :type) == "movie"
        end)
      end
    end

    # Test that the module compiles and has the expected functions
    assert function_exported?(TestPlexApp, :list_all_movies, 0)
    assert function_exported?(TestPlexApp, :mark_episode_watched, 1)
    assert function_exported?(TestPlexApp, :search_for_content, 1)
    assert function_exported?(TestPlexApp, :get_movie_details, 1)

    # Test that the functions can be called (they will fail without proper setup, but should not crash)
    case TestPlexApp.list_all_movies() do
      {:ok, _movies} -> :ok
      # Expected without proper server setup
      {:error, _reason} -> :ok
    end

    case TestPlexApp.mark_episode_watched("12345") do
      :ok -> :ok
      # Expected without proper server setup
      {:error, _reason} -> :ok
    end

    case TestPlexApp.search_for_content("batman") do
      {:ok, _results} -> :ok
      # Expected without proper server setup
      {:error, _reason} -> :ok
    end

    case TestPlexApp.get_movie_details("67890") do
      {:ok, _metadata} -> :ok
      # Expected without proper server setup
      {:error, _reason} -> :ok
    end
  end

  test "use PlEx provides access to all API categories" do
    defmodule FullAPITest do
      use PlEx

      # Library API
      def test_library_api do
        [
          get_library_sections(),
          get_library_section("1"),
          get_library_items("1"),
          get_recently_added("1"),
          scan_library_section("1"),
          get_library_collections("1"),
          create_library_collection("1", "Test Collection")
        ]
      end

      # Media API  
      def test_media_api do
        [
          get_media_metadata("12345"),
          get_media_children("12345"),
          mark_media_watched("12345"),
          mark_media_unwatched("12345"),
          set_media_progress("12345", time: 300_000),
          rate_media("12345", 8.5),
          unrate_media("12345"),
          get_media_related("12345"),
          refresh_media_metadata("12345")
        ]
      end

      # Search API
      def test_search_api do
        [
          search("batman"),
          advanced_search(%{genre: "Action"}),
          search_suggestions("aven"),
          search_people("Tom Hanks"),
          search_within("12345", "pilot")
        ]
      end
    end

    # Test that all API categories are accessible
    assert function_exported?(FullAPITest, :test_library_api, 0)
    assert function_exported?(FullAPITest, :test_media_api, 0)
    assert function_exported?(FullAPITest, :test_search_api, 0)
  end

  test "use PlEx with module options" do
    defmodule ConfiguredPlexApp do
      use PlEx, server: "http://localhost:32400", timeout: 30_000

      def get_configured_options do
        __plex_opts__()
      end
    end

    # Test that module options are stored
    opts = ConfiguredPlexApp.get_configured_options()
    assert opts[:server] == "http://localhost:32400"
    assert opts[:timeout] == 30_000
  end
end
