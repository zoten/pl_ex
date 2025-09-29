defmodule PlexCatalogReader.Application do
  @moduledoc """
  Application supervisor for the Plex Catalog Reader.

  Starts the necessary processes including HTTP client and PlEx.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # HTTP client for PlEx
      # {Finch, name: PlExFinch}
    ]

    opts = [strategy: :one_for_one, name: PlexCatalogReader.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
