defmodule PlexCatalogReader.MixProject do
  use Mix.Project

  def project do
    [
      app: :plex_catalog_reader,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PlexCatalogReader.Application, []}
    ]
  end

  defp deps do
    [
      {:pl_ex, path: "../.."},
      {:finch, "~> 0.18"},
      {:jason, "~> 1.4"}
    ]
  end
end
