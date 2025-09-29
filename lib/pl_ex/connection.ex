defmodule PlEx.Connection do
  @moduledoc """
  Connection management for PlEx.

  Handles connection state, server discovery, and connection pooling.
  """

  use GenServer

  @doc """
  Starts the connection manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current active connection.
  """
  def get_current do
    # ✅ Add timeout
    case GenServer.call(__MODULE__, :get_current, 1000) do
      nil -> nil
      connection -> connection
    end
  rescue
    # GenServer not started or timeout
    _ -> nil
  end

  @doc """
  Sets the current active connection.
  """
  def set_current(connection) do
    GenServer.call(__MODULE__, {:set_current, connection})
  rescue
    _ -> {:error, :connection_manager_not_started}
  end

  @doc """
  Clears the current connection.
  """
  def clear_current do
    GenServer.call(__MODULE__, :clear_current)
  rescue
    _ -> :ok
  end

  # GenServer implementation

  @impl true
  def init(_opts) do
    {:ok, %{current: nil}}
  end

  @impl true
  def handle_call(:get_current, _from, state) do
    {:reply, state.current, state}
  end

  @impl true
  def handle_call({:set_current, connection}, _from, state) do
    {:reply, :ok, %{state | current: connection}}
  end

  @impl true
  def handle_call(:clear_current, _from, state) do
    {:reply, :ok, %{state | current: nil}}
  end
end
