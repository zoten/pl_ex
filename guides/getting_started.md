# Getting Started with PlEx

This guide will walk you through setting up and using PlEx to interact with your Plex Media Server.

## Prerequisites

- Elixir 1.14+ and OTP 25+
- A running Plex Media Server
- Basic familiarity with Elixir

## Installation

Add PlEx to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:pl_ex, "~> 0.1.0"},
    {:finch, "~> 0.18"}  # HTTP client
  ]
end
```

Run `mix deps.get` to install the dependencies.

## Basic Setup

### 1. Application Configuration

Add Finch to your application supervision tree in `lib/your_app/application.ex`:

```elixir
def start(_type, _args) do
  children = [
    {Finch, name: PlExFinch},
    # ... your other children
  ]
  
  opts = [strategy: :one_for_one, name: YourApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 2. Configuration

Configure PlEx in `config/config.exs`:

```elixir
config :pl_ex,
  # Basic configuration
  default_server: "http://localhost:32400",  # Your Plex server URL
  auth_method: :jwt,
  
  # Optional: Performance tuning
  cache_ttl: 300,
  connection_pool_size: 10,
  request_timeout: 30_000
```

## Your First PlEx Application

Let's create a simple module that demonstrates the main PlEx features:

```elixir
defmodule MyPlexClient do
  use PlEx  # This gives you access to all PlEx API functions
  
  @doc "List all available library sections"
  def list_libraries do
    case get_library_sections() do
      {:ok, sections} ->
        sections
        |> Enum.map(fn section ->
          "#{section.title} (#{section.type}) - #{section.key}"
        end)
        |> Enum.join("\n")
        |> IO.puts()
        
      {:error, reason} ->
        IO.puts("Failed to get libraries: #{inspect(reason)}")
    end
  end
  
  @doc "Find and display movies in your library"
  def browse_movies(limit \\ 10) do
    with {:ok, sections} <- get_library_sections(),
         movie_section <- find_section_by_type(sections, "movie"),
         {:ok, movies} <- get_library_items(movie_section.key, type: :movie, limit: limit) do
      
      IO.puts("Found #{length(movies)} movies:")
      
      movies
      |> Enum.each(fn movie ->
        IO.puts("  • #{movie.title} (#{movie.year})")
      end)
      
      {:ok, movies}
    else
      nil -> 
        IO.puts("No movie library found")
        {:error, :no_movie_library}
        
      error -> 
        IO.puts("Error browsing movies: #{inspect(error)}")
        error
    end
  end
  
  @doc "Search for content across all libraries"
  def search_content(query) do
    case search(query, limit: 5) do
      {:ok, results} ->
        IO.puts("Search results for '#{query}':")
        
        results
        |> Enum.each(fn item ->
          IO.puts("  • #{item.title} (#{item.type})")
        end)
        
        {:ok, results}
        
      {:error, reason} ->
        IO.puts("Search failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc "Mark a movie as watched"
  def watch_movie(rating_key) do
    with {:ok, metadata} <- get_media_metadata(rating_key),
         :ok <- mark_media_watched(rating_key) do
      IO.puts("Marked '#{metadata.title}' as watched!")
      :ok
    else
      error ->
        IO.puts("Failed to mark as watched: #{inspect(error)}")
        error
    end
  end
  
  @doc "Get recently added content"
  def whats_new(section_key, limit \\ 5) do
    case get_recently_added(section_key, limit: limit) do
      {:ok, items} ->
        IO.puts("Recently added:")
        
        items
        |> Enum.each(fn item ->
          IO.puts("  • #{item.title} (added #{format_date(item.added_at)})")
        end)
        
        {:ok, items}
        
      {:error, reason} ->
        IO.puts("Failed to get recent items: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Helper functions
  
  defp find_section_by_type(sections, type) do
    Enum.find(sections, fn section -> section.type == type end)
  end
  
  defp format_date(timestamp) when is_integer(timestamp) do
    timestamp
    |> DateTime.from_unix!()
    |> DateTime.to_date()
    |> Date.to_string()
  end
  
  defp format_date(_), do: "unknown"
end
```

## Testing Your Setup

Start an IEx session and try out your new PlEx client:

```elixir
# Start IEx
iex -S mix

# List your libraries
MyPlexClient.list_libraries()

# Browse movies
MyPlexClient.browse_movies(5)

# Search for content
MyPlexClient.search_content("batman")

# Check what's new in your first library section
MyPlexClient.whats_new("1")
```

## Version Compatibility

PlEx automatically handles different Plex API versions. Some features are only available in newer versions:

```elixir
defmodule VersionAwareClient do
  use PlEx
  
  def try_collections(section_key) do
    case get_library_collections(section_key) do
      {:ok, collections} ->
        IO.puts("Collections are supported! Found #{length(collections)} collections.")
        {:ok, collections}
        
      {:error, :feature_not_supported} ->
        IO.puts("Collections not supported on this Plex version (requires v1.2.0+)")
        {:error, :not_supported}
        
      {:error, reason} ->
        IO.puts("Error getting collections: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  def check_server_capabilities do
    # This would require a real connection to work
    # PlEx.Version.Compatibility.compatibility_report(connection)
    IO.puts("Server capability checking requires a configured connection")
  end
end
```

## Advanced Features

### Custom Search with Filters

```elixir
defmodule AdvancedSearch do
  use PlEx
  
  def find_recent_action_movies do
    # Advanced search is available in v1.2.0+
    advanced_search(%{
      genre: "Action",
      year: {2020, 2024},
      type: :movie
    })
  end
  
  def search_with_suggestions(partial_title) do
    case search_suggestions(partial_title) do
      {:ok, suggestions} ->
        IO.puts("Did you mean: #{Enum.join(suggestions, ", ")}")
        {:ok, suggestions}
        
      {:error, :feature_not_supported} ->
        # Fallback to basic search
        search(partial_title)
    end
  end
end
```

### Media Management

```elixir
defmodule MediaManager do
  use PlEx
  
  def binge_watch_series(series_key) do
    with {:ok, episodes} <- get_media_children(series_key),
         watched_episodes <- mark_all_watched(episodes) do
      IO.puts("Marked #{length(watched_episodes)} episodes as watched!")
      {:ok, watched_episodes}
    end
  end
  
  def rate_and_review(rating_key, rating) do
    with :ok <- rate_media(rating_key, rating),
         {:ok, metadata} <- get_media_metadata(rating_key) do
      IO.puts("Rated '#{metadata.title}' #{rating}/10")
      :ok
    end
  end
  
  defp mark_all_watched(episodes) do
    episodes
    |> Enum.map(fn episode ->
      case mark_media_watched(episode.rating_key) do
        :ok -> episode
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
```

## Error Handling Best Practices

PlEx provides comprehensive error handling. Here are some patterns:

```elixir
defmodule RobustClient do
  use PlEx
  
  def safe_library_operation(section_key) do
    case get_library_items(section_key) do
      {:ok, items} ->
        process_items(items)
        
      {:error, :connection_failed} ->
        IO.puts("Could not connect to Plex server")
        {:error, :no_connection}
        
      {:error, :unauthorized} ->
        IO.puts("Authentication failed - check your credentials")
        {:error, :auth_failed}
        
      {:error, :feature_not_supported} ->
        IO.puts("This feature requires a newer Plex version")
        {:error, :version_too_old}
        
      {:error, reason} ->
        IO.puts("Unexpected error: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp process_items(items) do
    IO.puts("Processing #{length(items)} items...")
    {:ok, items}
  end
end
```

## Next Steps

Now that you have PlEx set up and working:

1. **Explore the API** - Check out the full API documentation
2. **Handle Authentication** - Set up proper authentication for production use
3. **Add Error Handling** - Implement robust error handling for your use case
4. **Performance Tuning** - Configure caching and connection pooling
5. **Testing** - Write tests for your PlEx integration

## Troubleshooting

### Common Issues

**"Connection refused"**
- Make sure your Plex Media Server is running
- Check the server URL in your configuration
- Verify network connectivity

**"Unauthorized"**
- Check your authentication configuration
- Ensure your Plex token is valid
- Verify server access permissions

**"Feature not supported"**
- Some features require newer Plex versions
- Check the version compatibility in the documentation
- Use feature detection to handle gracefully

### Getting Help

- Check the [API Documentation](https://hexdocs.pm/pl_ex)
- Look at the [examples directory](./examples)
- Open an issue on GitHub for bugs or feature requests

Happy coding with PlEx! 🎬✨
