#!/usr/bin/env elixir

# Basic PlEx Usage Example
# 
# This script demonstrates how to use PlEx in a real environment.
# Run with: elixir examples/basic_usage.exs

Mix.install([
  {:pl_ex, path: ".."},
  {:finch, "~> 0.18"}
])

defmodule PlexExample do
  use PlEx
  
  def run do
    IO.puts("🎬 PlEx Basic Usage Example")
    IO.puts("=" |> String.duplicate(30))
    
    # Step 1: Setup validation
    IO.puts("\n1. Validating setup...")
    case PlEx.Setup.validate_setup() do
      :ok -> 
        IO.puts("✅ Setup is valid!")
      {:error, issues} ->
        IO.puts("❌ Setup issues found:")
        Enum.each(issues, &IO.puts("  - #{&1}"))
        return {:error, :invalid_setup}
    end
    
    # Step 2: List library sections
    IO.puts("\n2. Getting library sections...")
    case get_library_sections() do
      {:ok, sections} ->
        IO.puts("✅ Found #{length(sections)} library sections:")
        Enum.each(sections, fn section ->
          IO.puts("  - #{section.title} (#{section.type})")
        end)
        
        # Step 3: Get items from first section
        if section = List.first(sections) do
          IO.puts("\n3. Getting items from '#{section.title}'...")
          case get_library_items(section.key, limit: 5) do
            {:ok, items} ->
              IO.puts("✅ Found #{length(items)} items:")
              Enum.each(items, fn item ->
                IO.puts("  - #{item.title} (#{item.year || "Unknown"})")
              end)
            
            {:error, reason} ->
              IO.puts("❌ Failed to get items: #{inspect(reason)}")
          end
        end
      
      {:error, reason} ->
        IO.puts("❌ Failed to get sections: #{inspect(reason)}")
        return {:error, reason}
    end
    
    # Step 4: Search example
    IO.puts("\n4. Searching for content...")
    case search("batman", limit: 3) do
      {:ok, results} ->
        IO.puts("✅ Found #{length(results)} search results:")
        Enum.each(results, fn item ->
          IO.puts("  - #{item.title} (#{item.year || "Unknown"})")
        end)
      
      {:error, reason} ->
        IO.puts("❌ Search failed: #{inspect(reason)}")
    end
    
    IO.puts("\n🎉 Example completed!")
    :ok
  end
  
  defp return(value), do: value
end

# Configuration Options (choose one):

# Option 1: Environment Variables (Recommended)
# export PLEX_TOKEN="your-token-here"
# export PLEX_SERVER_URL="http://localhost:32400"
# export PLEX_CLIENT_ID="plex-example-script"

# Option 2: Runtime Configuration
PlEx.APIClient.configure(
  # token: "your-token-here",  # Uncomment and add your token
  server: "http://localhost:32400",
  client_id: "plex-example-script",
  auth_method: :token
)

# Start required applications
{:ok, _} = Application.ensure_all_started(:finch)
{:ok, _} = Application.ensure_all_started(:pl_ex)

# Check if properly configured
case PlEx.APIClient.ready?() do
  true ->
    IO.puts("✅ PlEx is configured and ready!")
    PlexExample.run()
  
  false ->
    IO.puts("⚠️  PlEx is not fully configured.")
    IO.puts("Current status: #{inspect(PlEx.APIClient.status())}")
    IO.puts("\nRunning setup wizard...")
    PlEx.APIClient.setup_wizard()
end
