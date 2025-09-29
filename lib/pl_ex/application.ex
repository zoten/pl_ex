defmodule PlEx.Application do
  @moduledoc """
  PlEx Application supervisor.

  Starts the necessary processes for PlEx to function properly,
  including HTTP client pools and connection managers.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # HTTP client pool (if Finch is configured)
        finch_child_spec(),
        # Connection manager for maintaining server connections (only in non-test environments)
        connection_child_spec()
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: PlEx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp finch_child_spec do
    case PlEx.Config.http_adapter() do
      PlEx.HTTP.FinchAdapter ->
        finch_name = PlEx.Config.finch_name()

        # Check if Finch is already started (e.g., in tests)
        case Process.whereis(finch_name) do
          nil ->
            # Start Finch if not already running
            pool_size = PlEx.Config.connection_pool_size()

            {Finch,
             name: finch_name,
             pools: %{
               :default => [size: pool_size, count: 1]
             }}

          _pid ->
            # Finch already running, don't start it again
            nil
        end

      _ ->
        nil
    end
  end

  defp connection_child_spec do
    # Don't start connection manager in test environment to avoid conflicts
    if Application.get_env(:pl_ex, :env, :dev) != :test do
      PlEx.Connection
    else
      nil
    end
  end
end
