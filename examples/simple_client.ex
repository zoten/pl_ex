#!/usr/bin/env elixir

# Simple PlEx Client Example
# 
# This example shows the easiest way to get started with PlEx
# using environment variables for configuration.

Mix.install([
  {:pl_ex, path: ".."},
  {:finch, "~> 0.18"}
])

defmodule Examples.SimpleClient do
  @moduledoc """
  Simple PlEx client demonstrating basic usage with environment variables.
  
  ## Setup
  
  Set these environment variables:
  
      export PLEX_TOKEN="your-plex-token"
      export PLEX_SERVER_URL="http://localhost:32400"
      export PLEX_CLIENT_ID="simple-client-example"
  
  Then run:
  
      elixir examples/simple_client.ex
  """
  
  def run do
    IO.puts("🎬 Simple PlEx Client Example")
    IO.puts("=" |> String.duplicate(30))
    
    # Check configuration
    IO.puts("\n📋 Configuration Status:")
    status = PlEx.APIClient.status()
    IO.inspect(status, pretty: true)
    
    unless PlEx.APIClient.ready?() do
      IO.puts("\n⚠️  Not fully configured. Running setup wizard...")
      PlEx.APIClient.setup_wizard()
    end
    
    # Test connection
    IO.puts("\n🔍 Testing connection...")
    case PlEx.APIClient.test_connection() do
      {:ok, info} ->
        IO.puts("✅ Connected to #{info.server}")
        IO.puts("   Machine ID: #{info.machine_id}")
        
        # List movies
        list_movies()
        
        # Search example
        search_example()
        
      {:error, reason} ->
        IO.puts("❌ Connection failed: #{inspect(reason)}")
        IO.puts("Please check your configuration.")
    end
  end
  
  defp list_movies do
    IO.puts("\n🎭 Your Movie Libraries:")
    
    case PlEx.APIClient.get_library_sections() do
      {:ok, sections} ->
        movie_sections = Enum.filter(sections, &(&1.type == "movie"))
        
        if Enum.empty?(movie_sections) do
          IO.puts("   No movie libraries found.")
        else
          Enum.each(movie_sections, fn section ->
            IO.puts("   📁 #{section.title}")
            
            # Get a few movies from this section
            case PlEx.APIClient.get_library_items(section.key, limit: 3) do
              {:ok, movies} ->
                Enum.each(movies, fn movie ->
                  year = if movie.year, do: " (#{movie.year})", else: ""
                  IO.puts("      • #{movie.title}#{year}")
                end)
              
              {:error, _} ->
                IO.puts("      (Could not load movies)")
            end
          end)
        end
      
      {:error, reason} ->
        IO.puts("   ❌ Failed to get libraries: #{inspect(reason)}")
    end
  end
  
  defp search_example do
    IO.puts("\n🔍 Search Example (searching for 'star'):")
    
    case PlEx.APIClient.search("star", limit: 3) do
      {:ok, results} ->
        if Enum.empty?(results) do
          IO.puts("   No results found.")
        else
          Enum.each(results, fn item ->
            year = if item.year, do: " (#{item.year})", else: ""
            IO.puts("   🎬 #{item.title}#{year}")
          end)
        end
      
      {:error, reason} ->
        IO.puts("   ❌ Search failed: #{inspect(reason)}")
    end
  end
end

# Start applications
{:ok, _} = Application.ensure_all_started(:finch)
{:ok, _} = Application.ensure_all_started(:pl_ex)

# Run the example
Examples.SimpleClient.run()
