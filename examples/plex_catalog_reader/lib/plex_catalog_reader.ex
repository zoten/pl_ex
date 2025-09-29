defmodule PlexCatalogReader do
  @moduledoc """
  Plex Catalog Reader - Example application using PlEx with environment variables.

  ## Setup

      export PLEX_TOKEN="your-plex-token-here"
      export PLEX_SERVER_URL="http://192.168.1.100:32400"
      export PLEX_CLIENT_ID="plex-catalog-reader"

  ## Usage

      mix run -e "PlexCatalogReader.run()"
  """

  require Logger

  def run do
    IO.puts("📚 Plex Catalog Reader\n======================")

    case validate_environment() do
      :ok -> read_catalog()
      {:error, missing} -> show_missing_vars(missing)
    end
  end

  def read_catalog do
    configure_plex()

    case PlEx.APIClient.test_connection() do
      {:ok, info} ->
        IO.puts("✅ Connected to #{info.server}")
        read_all_titles()

      {:error, reason} ->
        IO.puts("❌ Connection failed: #{inspect(reason)}")
    end
  end

  defp read_all_titles do
    case PlEx.get_library_sections() do
      {:ok, sections} ->
        IO.puts("\n📁 Found #{length(sections)} library sections:")

        Enum.each(sections, fn section ->
          IO.puts("\n📂 #{section.title} (#{section.type})")

          case PlEx.get_library_items(section.key, limit: 50) do
            {:ok, items} ->
              IO.puts("   #{length(items)} items:")

              items
              |> Enum.take(10)
              |> Enum.each(fn item ->
                year = if item.year, do: " (#{item.year})", else: ""
                IO.puts("   • #{item.title}#{year}")
              end)

              if length(items) > 10 do
                IO.puts("   ... and #{length(items) - 10} more")
              end

            {:error, reason} ->
              IO.puts("   ❌ Failed to read items: #{inspect(reason)}")
          end
        end)

        IO.puts("\n🎉 Catalog reading complete!")

      {:error, reason} ->
        IO.puts("❌ Failed to get sections: #{inspect(reason)}")
    end
  end

  defp validate_environment do
    required = ["PLEX_TOKEN", "PLEX_SERVER_URL"]
    missing = Enum.filter(required, &(System.get_env(&1) == nil))

    if Enum.empty?(missing), do: :ok, else: {:error, missing}
  end

  defp configure_plex do
    PlEx.APIClient.configure(
      token: System.get_env("PLEX_TOKEN"),
      server: System.get_env("PLEX_SERVER_URL"),
      client_id: System.get_env("PLEX_CLIENT_ID") || "plex-catalog-reader"
    )
  end

  defp show_missing_vars(missing) do
    IO.puts("❌ Missing environment variables:")
    Enum.each(missing, &IO.puts("   - #{&1}"))
    IO.puts("\nSet them like this:")
    IO.puts("export PLEX_TOKEN=\"your-token\"")
    IO.puts("export PLEX_SERVER_URL=\"http://192.168.1.100:32400\"")
  end
end
