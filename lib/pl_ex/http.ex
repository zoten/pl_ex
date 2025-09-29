defmodule PlEx.HTTP do
  @moduledoc """
  Behaviour for HTTP adapters used by PlEx.

  Implementations wrap a concrete HTTP client (Finch, Mint, Tesla, :hackney, etc.).
  """

  @type method :: :get | :post | :put | :patch | :delete
  @type headers :: [{String.t(), String.t()}]

  @callback request(
              method(),
              url :: String.t(),
              headers(),
              body :: iodata() | nil,
              opts :: keyword()
            ) ::
              {:ok, %{status: non_neg_integer(), headers: headers(), body: binary()}}
              | {:error, term()}
end
