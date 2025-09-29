defmodule PlEx.HTTP.FinchAdapter do
  @moduledoc """
  Finch-based implementation of `PlEx.HTTP`.

  Note: Finch requires a started Finch pool in the host application, e.g.

      children = [
        {Finch, name: PlExFinch}
      ]

  Configure the name via `:pl_ex, :finch_name` (defaults to `PlExFinch`).
  """
  @behaviour PlEx.HTTP

  @impl true
  def request(method, url, headers, body, opts) do
    name = Keyword.get(opts, :finch_name, Application.get_env(:pl_ex, :finch_name, PlExFinch))
    finch_req = Finch.build(method, url, headers, body)

    case Finch.request(finch_req, name) do
      {:ok, %Finch.Response{status: status, headers: resp_headers, body: resp_body}} ->
        {:ok, %{status: status, headers: resp_headers, body: resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
