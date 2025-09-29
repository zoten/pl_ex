# PlEx 🎬

⚠️ This repository has been strongly aided by AI tooling. I still have to deeply review the code to ensure safety and correctness, and am using it only for my personal home purposes. I will remove this disclaimer (and publish on hex) once I'll be decently sure about the quality of the project

**A comprehensive, version-adaptive Elixir SDK for the Plex Media Server API**

PlEx provides a modern, type-safe, and developer-friendly way to interact with Plex Media Servers.

## ✨ Key Features

- **🔄 Version-Adaptive** - Automatically detects and adapts to different Plex API versions
- **🛡️ Type-Safe** - Full Elixir structs with comprehensive validation  
- **🚀 Developer-Friendly** - Simple `use PlEx` macro provides instant access to all APIs
- **📚 Complete API Coverage** - Library, Media, Search, and Collection management
- **🔐 Modern Authentication** - JWT and legacy token authentication
- **⚡ High Performance** - Built-in caching, connection pooling, and retry logic

## Installation

Add `pl_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # not published on hex at the moment!
    {:pl_ex, git: "https://github.com/zoten/pl_ex"},
    {:finch, "~> 0.18"}  # Default HTTP client
  ]
end
```

## 🚀 Quick Start

### Method 1: Environment Variables (Recommended)

The easiest way to get started is using environment variables:

```bash
# Set your Plex credentials
export PLEX_TOKEN="your-plex-token-here"
export PLEX_SERVER_URL="http://localhost:32400"
export PLEX_CLIENT_ID="my-app-v1.0"
```

```elixir
# That's it! PlEx will automatically use environment variables
defmodule MyPlexApp do
  def run do
    # Check if ready
    unless PlEx.APIClient.ready?() do
      PlEx.APIClient.setup_wizard()  # Interactive setup if needed
    end
    
    # Use PlEx APIs directly
    {:ok, sections} = PlEx.APIClient.get_library_sections()
    {:ok, results} = PlEx.APIClient.search("batman")
    
    IO.puts("Found #{length(sections)} library sections")
    IO.puts("Found #{length(results)} search results")
  end
end
```

### Method 2: Runtime Configuration

```elixir
# Configure at runtime
PlEx.APIClient.configure(
  token: "your-plex-token-here",
  server: "http://localhost:32400",
  client_id: "my-app-v1.0"
)

# Test connection
case PlEx.APIClient.test_connection() do
  {:ok, info} -> IO.puts("✅ Connected to #{info.server}")
  {:error, reason} -> IO.puts("❌ Failed: #{inspect(reason)}")
end
```

### Method 3: Advanced Usage with `use PlEx`

```elixir
defmodule MyPlexApp do
  use PlEx  # Injects all PlEx API functions
  
  def list_movies do
    with {:ok, sections} <- get_library_sections(),
         movie_section <- find_movie_section(sections),
         {:ok, movies} <- get_library_items(movie_section.key, type: :movie) do
      {:ok, movies}
    end
  end
  
  def search_and_watch(title) do
    with {:ok, results} <- search(title, type: :movie),
         movie <- List.first(results),
         :ok <- mark_media_watched(movie.rating_key) do
      {:ok, "Now watching: #{movie.title}"}
    end
  end
  
  defp find_movie_section(sections) do
    Enum.find(sections, &(&1.type == "movie"))
  end
end
```

### 1. Setup

Add PlEx to your application supervision tree:

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    {Finch, name: PlExFinch},  # Required for HTTP requests
    # ... your other children
  ]
  
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 2. Get Your Plex Token

You need a Plex authentication token. Here's how to get one:

**Option A: From Plex Web App** (Official Method)
1. [Sign in to your Plex account](https://app.plex.tv) in Plex Web App
2. Browse to any library item (movie, show, etc.)
3. Click the "View XML" option (usually under the "..." menu or by adding `.xml` to the URL)
4. Look in the URL bar - your token appears as the `X-Plex-Token` parameter value

### 3. Configuration

Configure PlEx in your `config/config.exs`:

```elixir
config :pl_ex,
  # Required: Unique identifier for your application
  client_identifier: "your-unique-client-id",
  
  # Application metadata (sent in X-Plex-* headers)
  product: "My Awesome App",
  version: "1.0.0",
  platform: :elixir,
  device: "server",
  device_name: "my-app-server",
  
  # Authentication method - choose one:
  # Option 1: Token authentication (simple, recommended for most users)
  auth_provider: PlEx.Auth.Token,
  legacy_token: "your-plex-token-here",  # Or use PLEX_TOKEN env var
  
  # Option 2: JWT authentication (more secure, auto-refresh)
  # auth_provider: PlEx.Auth.JWT,
  
  # HTTP and JSON libraries
  http_adapter: PlEx.HTTP.FinchAdapter,
  finch_name: PlExFinch
```

### 4. Authentication Methods

#### Token Authentication (Recommended for Most Users)

Simple and reliable using your Plex token:

```bash
# Method 1: Environment variable (recommended)
export PLEX_TOKEN="your-plex-token-here"
```

```elixir
# Method 2: Application config
config :pl_ex,
  auth_provider: PlEx.Auth.Token,
  legacy_token: "your-plex-token-here"

# Method 3: Runtime configuration
PlEx.APIClient.configure(token: "your-plex-token-here")
```

#### JWT Authentication (Advanced)

More secure with automatic token refresh:

```elixir
config :pl_ex, auth_provider: PlEx.Auth.JWT

# PlEx will automatically handle JWT authentication
{:ok, sections} = PlEx.API.Library.get_sections()
```

#### Environment Variable Support

PlEx automatically reads from these environment variables:

- `PLEX_TOKEN` or `PLEX_API_KEY` - Your Plex authentication token
- `PLEX_SERVER_URL` or `PLEX_URL` - Your Plex server URL  
- `PLEX_CLIENT_ID` or `PLEX_CLIENT_IDENTIFIER` - Your app's client ID

```bash
# Set once and forget
export PLEX_TOKEN="abc123def456"
export PLEX_SERVER_URL="http://localhost:32400"
export PLEX_CLIENT_ID="my-elixir-app"
```

## Usage Examples

### Discover Plex Media Servers

```elixir
# Discover available PMS instances
{:ok, connections} = PlEx.Resources.discover([])

# Choose the best connection (local > direct > relay)
{:ok, %{base_url: url, access_token: token, server: server}} = 
  PlEx.Resources.choose_connection(connections)

IO.puts("Connected to: #{server["name"]} at #{url}")
```

### Library API

```elixir
# Get all library sections
{:ok, sections} = PlEx.API.Library.get_sections()

# Get a specific section
{:ok, section} = PlEx.API.Library.get_section("1")

# Get items from a section
{:ok, movies} = PlEx.API.Library.get_items("1", type: :movie)

# Get recently added items
{:ok, recent} = PlEx.API.Library.get_recently_added("1")

# Create a collection
{:ok, collection} = PlEx.API.Library.create_collection("1", "My Collection")

# Scan a library section
:ok = PlEx.API.Library.scan_section("1")
```

### Media API

```elixir
# Get media metadata
{:ok, movie} = PlEx.API.Media.get_metadata("12345")

# Get media children (episodes, etc.)
{:ok, children} = PlEx.API.Media.get_children("12345")

# Mark as watched/unwatched
:ok = PlEx.API.Media.mark_watched("12345")
:ok = PlEx.API.Media.mark_unwatched("12345")

# Rate media
:ok = PlEx.API.Media.rate("12345", 8.5)
:ok = PlEx.API.Media.unrate("12345")
```

### Search API

```elixir
# Basic search
{:ok, results} = PlEx.API.Search.search("batman")

# Advanced search with filters
{:ok, results} = PlEx.API.Search.advanced_search(%{
  genre: "Action",
  year: 2020..2023
})

# Get search suggestions
{:ok, suggestions} = PlEx.API.Search.get_suggestions("bat")

# Search for people
{:ok, people} = PlEx.API.Search.search_people("Tom Hanks")

# Search within a specific item
{:ok, episodes} = PlEx.API.Search.search_within("12345", "pilot")
```

### Transport Layer

Make direct API calls using the transport layer:

```elixir
# Call plex.tv endpoints
{:ok, user_info} = PlEx.Transport.request(:plex_tv, :get, "/api/v2/user", [])

# Call PMS endpoints  
{:ok, libraries} = PlEx.Transport.request(:pms, :get, "/library/sections", [])

# With custom options
{:ok, response} = PlEx.Transport.request(:pms, :get, "/library/sections", [
  retries: 5,
  backoff_base_ms: 500,
  credentials_provider: {PlEx.Auth.LegacyToken, token: "custom-token"}
])
```

### Custom HTTP Adapter

```elixir
defmodule MyApp.TeslaAdapter do
  @behaviour PlEx.HTTP
  
  @impl true
  def request(method, url, headers, body, _opts) do
    case Tesla.request(%Tesla.Env{
      method: method,
      url: url, 
      headers: headers,
      body: body
    }) do
      {:ok, %Tesla.Env{status: status, headers: resp_headers, body: resp_body}} ->
        {:ok, %{status: status, headers: resp_headers, body: resp_body}}
      {:error, reason} -> 
        {:error, reason}
    end
  end
end

# Configure it
config :pl_ex, http_adapter: MyApp.TeslaAdapter
```

### Secure Storage

For production, implement secure storage for keys and tokens:

```elixir
defmodule MyApp.SecureStorage do
  @behaviour PlEx.Auth.Storage
  
  @impl true
  def get(key), do: MyApp.Vault.get(key)
  
  @impl true  
  def put(key, value), do: MyApp.Vault.put(key, value)
  
  @impl true
  def delete(key), do: MyApp.Vault.delete(key)
end

config :pl_ex, storage: MyApp.SecureStorage
```

## Error Handling

PlEx includes automatic retry logic and error recovery:

```elixir
case PlEx.Transport.request(:pms, :get, "/library/sections", []) do
  {:ok, response} -> 
    # Success
    handle_response(response)
    
  {:error, {:http_error, 401, _body}} ->
    # Unauthorized - token may have expired
    # PlEx automatically tries to refresh tokens
    
  {:error, {:http_error, 498, _body}} ->
    # Token expired - PlEx will refresh and retry
    
  {:error, reason} ->
    # Other errors (network, etc.)
    Logger.error("Request failed: #{inspect(reason)}")
end
```

## Architecture

PlEx follows a modular architecture with pluggable components:

- **Transport Layer** (`PlEx.Transport`) - HTTP request handling with retry logic
- **Authentication** (`PlEx.Auth.*`) - JWT and legacy token providers  
- **Resources** (`PlEx.Resources`) - PMS discovery and connection selection
- **HTTP Adapters** (`PlEx.HTTP.*`) - Support for multiple HTTP clients
- **Storage** (`PlEx.Auth.Storage.*`) - Pluggable key/token storage
- **Version Management** (`PlEx.Version.*`) - API version detection and adaptation

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/pl_ex>.

