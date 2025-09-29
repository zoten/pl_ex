defmodule PlEx.Auth.Storage.InMemory do
  @moduledoc """
  Simple ETS-based storage suitable for tests and development.

  Note: This is not secure storage. For production, implement a module
  that uses OS keyring, HSM, or a secure vault and configure it via :pl_ex.
  """
  @behaviour PlEx.Auth.Storage

  @table __MODULE__

  # ✅ Initialize table once at module load time
  def __init__ do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, read_concurrency: true, write_concurrency: true])

      _ ->
        :ok
    end
  end

  @impl true
  def get(key) do
    # ✅ Ensure table exists, but use try/catch for performance
    try do
      case :ets.lookup(@table, key) do
        [{^key, value}] -> {:ok, value}
        _ -> :error
      end
    catch
      :error, :badarg ->
        __init__()
        get(key)
    end
  end

  @impl true
  def put(key, value) do
    try do
      true = :ets.insert(@table, {key, value})
      :ok
    catch
      :error, :badarg ->
        __init__()
        put(key, value)
    end
  end

  @impl true
  def delete(key) do
    try do
      :ets.delete(@table, key)
      :ok
    catch
      :error, :badarg ->
        __init__()
        delete(key)
    end
  end
end
