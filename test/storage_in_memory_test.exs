defmodule PlEx.Auth.Storage.InMemoryTest do
  use ExUnit.Case, async: true

  alias PlEx.Auth.Storage.InMemory

  test "put/get/delete roundtrip" do
    key = {:test, :key}
    assert :error == InMemory.get(key)

    assert :ok == InMemory.put(key, 123)
    assert {:ok, 123} == InMemory.get(key)

    assert :ok == InMemory.delete(key)
    assert :error == InMemory.get(key)
  end
end
