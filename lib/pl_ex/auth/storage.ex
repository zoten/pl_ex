defmodule PlEx.Auth.Storage do
  @moduledoc """
  Behaviour for pluggable token and key storage used by authentication providers.

  Implementations should provide simple get/put/delete primitives.
  """

  @callback get(key :: term()) :: {:ok, term()} | :error
  @callback put(key :: term(), value :: term()) :: :ok
  @callback delete(key :: term()) :: :ok
end
