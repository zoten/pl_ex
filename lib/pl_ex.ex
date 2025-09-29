defmodule PlEx do
  @moduledoc """
  PlEx - Plex Media Server SDK for Elixir

  A comprehensive SDK for interacting with Plex Media Server APIs with automatic
  version detection, authentication, and response parsing.

  ## Usage

      defmodule MyPlexApp do
        use PlEx
        
        def list_movies do
          # Direct access to all PlEx API functions
          with {:ok, sections} <- get_library_sections(),
               movie_section <- find_movie_section(sections),
               {:ok, movies} <- get_library_items(movie_section.key, type: :movie) do
            {:ok, movies}
          end
        end
        
        def mark_episode_watched(episode_key) do
          mark_media_watched(episode_key)
        end
      end

  ## Configuration

  PlEx can be configured in your application config:

      config :pl_ex,
        default_server: "http://localhost:32400",
        auth_method: :jwt,
        cache_ttl: 300,
        connection_pool_size: 10

  ## Features

  - **Version-Adaptive**: Automatically detects and adapts to different Plex API versions
  - **Authentication**: Supports multiple auth methods (JWT, legacy token, PIN-based)
  - **Type Safety**: Full Elixir structs with proper typing
  - **Caching**: Built-in response caching for better performance
  - **Error Handling**: Comprehensive error handling with helpful messages
  """

  alias PlEx.{API}

  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      # Import all the main API functions
      import PlEx,
        only: [
          # Library API
          get_library_sections: 0,
          get_library_sections: 1,
          get_library_section: 1,
          get_library_section: 2,
          get_library_items: 1,
          get_library_items: 2,
          get_recently_added: 1,
          get_recently_added: 2,
          scan_library_section: 1,
          scan_library_section: 2,
          get_library_collections: 1,
          get_library_collections: 2,
          create_library_collection: 2,
          create_library_collection: 3,

          # Media API
          get_media_metadata: 1,
          get_media_metadata: 2,
          get_media_children: 1,
          get_media_children: 2,
          mark_media_watched: 1,
          mark_media_watched: 2,
          mark_media_unwatched: 1,
          mark_media_unwatched: 2,
          set_media_progress: 2,
          set_media_progress: 3,
          rate_media: 2,
          rate_media: 3,
          unrate_media: 1,
          unrate_media: 2,
          get_media_related: 1,
          get_media_related: 2,
          refresh_media_metadata: 1,
          refresh_media_metadata: 2,

          # Search API
          search: 1,
          search: 2,
          advanced_search: 1,
          advanced_search: 2,
          search_suggestions: 1,
          search_suggestions: 2,
          search_people: 1,
          search_people: 2,
          search_within: 2,
          search_within: 3
        ]

      # Store module-level options
      @plex_opts opts

      # Initialize connection on module compilation if configured
      @before_compile PlEx
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Module has been compiled, we can now set up any module-specific configuration
      def __plex_opts__, do: @plex_opts
    end
  end

  # Library API convenience functions

  @doc "Gets all library sections"
  def get_library_sections(opts \\ []), do: API.Library.get_sections(opts)

  @doc "Gets a specific library section"
  def get_library_section(key, opts \\ []), do: API.Library.get_section(key, opts)

  @doc "Gets items from a library section"
  def get_library_items(section_key, opts \\ []), do: API.Library.get_items(section_key, opts)

  @doc "Gets recently added items from a library section"
  def get_recently_added(section_key, opts \\ []),
    do: API.Library.get_recently_added(section_key, opts)

  @doc "Scans a library section for new content"
  def scan_library_section(section_key, opts \\ []),
    do: API.Library.scan_section(section_key, opts)

  @doc "Gets collections from a library section"
  def get_library_collections(section_key, opts \\ []),
    do: API.Library.get_collections(section_key, opts)

  @doc "Creates a new collection in a library section"
  def create_library_collection(section_key, title, opts \\ []),
    do: API.Library.create_collection(section_key, title, opts)

  # Media API convenience functions

  @doc "Gets metadata for a media item"
  def get_media_metadata(rating_key, opts \\ []), do: API.Media.get_metadata(rating_key, opts)

  @doc "Gets children of a media item"
  def get_media_children(rating_key, opts \\ []), do: API.Media.get_children(rating_key, opts)

  @doc "Marks a media item as watched"
  def mark_media_watched(rating_key, opts \\ []), do: API.Media.mark_watched(rating_key, opts)

  @doc "Marks a media item as unwatched"
  def mark_media_unwatched(rating_key, opts \\ []), do: API.Media.mark_unwatched(rating_key, opts)

  @doc "Sets playback progress for a media item"
  def set_media_progress(rating_key, progress_opts, opts \\ []),
    do: API.Media.set_progress(rating_key, Keyword.merge(progress_opts, opts))

  @doc "Rates a media item"
  def rate_media(rating_key, rating, opts \\ []), do: API.Media.rate(rating_key, rating, opts)

  @doc "Removes rating from a media item"
  def unrate_media(rating_key, opts \\ []), do: API.Media.unrate(rating_key, opts)

  @doc "Gets related media items"
  def get_media_related(rating_key, opts \\ []), do: API.Media.get_related(rating_key, opts)

  @doc "Refreshes metadata for a media item"
  def refresh_media_metadata(rating_key, opts \\ []),
    do: API.Media.refresh_metadata(rating_key, opts)

  # Search API convenience functions

  @doc "Performs a search across libraries"
  def search(query, opts \\ []), do: API.Search.search(query, opts)

  @doc "Performs an advanced search with filters"
  def advanced_search(filters, opts \\ []), do: API.Search.advanced_search(filters, opts)

  @doc "Gets search suggestions"
  def search_suggestions(partial_query, opts \\ []),
    do: API.Search.get_suggestions(partial_query, opts)

  @doc "Searches for people"
  def search_people(query, opts \\ []), do: API.Search.search_people(query, opts)

  @doc "Searches within a specific media item"
  def search_within(parent_key, query, opts \\ []),
    do: API.Search.search_within(parent_key, query, opts)
end
