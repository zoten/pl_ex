#!/usr/bin/env elixir

# Quick connection test script for Plex Catalog Reader
# 
# This script tests your Plex connection without reading the full catalog.
# Useful for verifying your environment variables are set correctly.

Mix.install([
  {:pl_ex, path: "../.."},
  {:finch, "~> 0.18"}
])

defmodule ConnectionTest do
  def run do
    IO.puts("🔍 Testing Plex Connection")
    IO.puts("=" |> String.duplicate(26))
    
    # Check environment variables
    IO.puts("\n📋 Environment Variables:")
    
    token = System.get_env("PLEX_TOKEN")
    server = System.get_env("PLEX_SERVER_URL")
    client_id = System.get_env("PLEX_CLIENT_ID") || "connection-test"
    
    IO.puts("   PLEX_TOKEN: #{if token, do: "[SET]", else: "[MISSING]"}")
    IO.puts("   PLEX_SERVER_URL: #{server || "[MISSING]"}")
    IO.puts("   PLEX_CLIENT_ID: #{client_id}")
    
    # Validate required variables
    missing = []
    missing = if token, do: missing, else: ["PLEX_TOKEN" | missing]
    missing = if server, do: missing, else: ["PLEX_SERVER_URL" | missing]
    
    unless Enum.empty?(missing) do
      IO.puts("\n❌ Missing required environment variables:")
      Enum.each(missing, fn var -> IO.puts("   - #{var}") end)
      IO.puts("\nPlease set them and try again.")
      System.halt(1)
    end
    
    # Configure PlEx
    PlEx.APIClient.configure(
      token: token,
      server: server,
      client_id: client_id
    )
    
    # Test connection
    IO.puts("\n🔗 Testing Connection...")
    
    case PlEx.APIClient.test_connection() do
      {:ok, info} ->
        IO.puts("✅ Connection successful!")
        IO.puts("   Server: #{info.server}")
        IO.puts("   Machine ID: #{info.machine_id}")
        IO.puts("   Version: #{info.version}")
        IO.puts("   Platform: #{info.platform}")
        
        # Try to get library sections count
        case PlEx.APIClient.get_library_sections() do
          {:ok, sections} ->
            IO.puts("\n📚 Library Information:")
            IO.puts("   Total Sections: #{length(sections)}")
            
            if length(sections) > 0 do
              IO.puts("   Section Types:")
              sections
              |> Enum.group_by(& &1.type)
              |> Enum.each(fn {type, sections_of_type} ->
                IO.puts("     - #{type}: #{length(sections_of_type)} section(s)")
              end)
            end
            
            IO.puts("\n🎉 Your Plex server is ready for catalog reading!")
            
          {:error, reason} ->
            IO.puts("\n⚠️  Connected but failed to read libraries:")
            IO.puts("   Error: #{inspect(reason)}")
            IO.puts("   This might be a permissions issue.")
        end
        
      {:error, reason} ->
        IO.puts("❌ Connection failed!")
        IO.puts("   Error: #{inspect(reason)}")
        
        IO.puts("\n🔧 Troubleshooting:")
        IO.puts("   1. Check if your Plex server is running")
        IO.puts("   2. Verify the server URL is correct")
        IO.puts("   3. Ensure your token is valid")
        IO.puts("   4. Try accessing #{server} in your browser")
        
        System.halt(1)
    end
  end
end

# Start required applications
{:ok, _} = Application.ensure_all_started(:finch)
{:ok, _} = Application.ensure_all_started(:pl_ex)

# Run the test
ConnectionTest.run()
