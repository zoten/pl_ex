defmodule PlEx.Transport do
  @moduledoc """
  Transport middleware (scaffold) that wraps the configured HTTP adapter.

  Responsibilities:
  - Inject required headers (`X-Plex-*`, `Accept: application/json`)
  - Attach the appropriate token depending on target (plex.tv vs PMS)
  - Handle retry/backoff and error mapping (498/422/429/401)

  This is a placeholder; concrete implementation will be added with the HTTP adapters.
  """

  alias PlEx.{Config, Error}

  @type method :: :get | :post | :put | :patch | :delete

  # Default retry configuration
  @default_retries 3
  # @default_backoff_base_ms 200  # Now using Config.backoff_base_ms()

  # HTTP status codes that trigger retries (currently using specific checks in code)
  # @retryable_statuses [498, 422, 429, 500, 502, 503, 504]

  # HTTP status codes that trigger auth invalidation
  @auth_error_statuses [401, 498]

  # Plex.tv base URL
  @plex_tv_base_url "https://plex.tv"

  # Backoff configuration
  @backoff_jitter_factor 0.2

  @spec request(:plex_tv | :pms, method(), String.t(), keyword()) ::
          {:ok, any()} | {:error, term()}
  def request(target, method, path_or_url, opts \\ []) do
    retries = Keyword.get(opts, :retries, Config.retries())
    backoff_base = Keyword.get(opts, :backoff_base_ms, Config.backoff_base_ms())

    do_request(target, method, path_or_url, opts, retries, backoff_base)
  end

  defp do_request(target, method, path_or_url, opts, retries, backoff_base) do
    headers = base_headers(opts)

    case attach_auth_and_url(target, path_or_url, headers, opts) do
      {:ok, url, headers} ->
        adapter = resolve_http_adapter(opts)
        body = Keyword.get(opts, :body)
        http_opts = Keyword.get(opts, :http_opts, [])

        case adapter.request(method, url, headers, body, http_opts) do
          {:ok, %{status: status, headers: resp_headers, body: resp_body}} ->
            handle_response(
              target,
              method,
              path_or_url,
              opts,
              retries,
              backoff_base,
              status,
              resp_headers,
              resp_body
            )

          {:error, reason} ->
            maybe_retry_on_error(target, method, path_or_url, opts, retries, backoff_base, reason)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_response(
         target,
         method,
         path_or_url,
         opts,
         retries,
         backoff_base,
         status,
         resp_headers,
         resp_body
       ) do
    cond do
      status in 200..299 ->
        {:ok, decode_body(resp_headers, resp_body)}

      status == 429 and retries > 0 ->
        sleep(backoff_base, retries)
        do_request(target, method, path_or_url, opts, retries - 1, backoff_base)

      status in @auth_error_statuses and retries > 0 ->
        # Let the credentials provider refresh/invalidate if provided
        maybe_recover_auth(target, opts)
        sleep(backoff_base, retries)
        do_request(target, method, path_or_url, opts, retries - 1, backoff_base)

      true ->
        {:error, Error.http_error(status, resp_body)}
    end
  end

  defp decode_body(headers, body) do
    ct =
      Enum.find_value(headers, fn {k, v} ->
        if String.downcase(k) == "content-type", do: v, else: nil
      end) || ""

    if String.contains?(ct, "application/json") do
      case Jason.decode(body) do
        {:ok, json} -> json
        _ -> body
      end
    else
      body
    end
  end

  defp base_headers(opts) do
    accept = Keyword.get(opts, :accept, "application/json")
    [{"Accept", accept} | Config.plex_headers()]
  end

  defp attach_auth_and_url(:plex_tv, path_or_url, headers, opts) do
    # Some endpoints (like nonce) don't require auth
    if Keyword.get(opts, :skip_auth, false) do
      url = build_plex_tv_url(path_or_url)
      {:ok, url, headers}
    else
      provider = resolve_provider(opts)

      with {:ok, {token, _exp}} <- provider.plex_token(provider_opts(opts)) do
        headers = [{"X-Plex-Token", token} | headers]
        url = build_plex_tv_url(path_or_url)
        {:ok, url, headers}
      end
    end
  end

  defp attach_auth_and_url(:pms, path, headers, opts) do
    provider = resolve_provider(opts)

    with {:ok, %{base_url: base_url, access_token: access_token}} <-
           provider.pms_connection(provider_opts(opts)) do
      headers = [{"X-Plex-Token", access_token} | headers]
      url = base_url <> path
      {:ok, url, headers}
    end
  end

  defp build_plex_tv_url(path_or_url) do
    if String.starts_with?(path_or_url, "http") do
      path_or_url
    else
      @plex_tv_base_url <> path_or_url
    end
  end

  # Resolve HTTP adapter. Allows per-request override via opts[:http_adapter]
  # falling back to the configured default in PlEx.Config.
  defp resolve_http_adapter(opts) do
    Keyword.get(opts, :http_adapter) || Config.http_adapter()
  end

  defp resolve_provider(opts) do
    case Keyword.get(opts, :credentials_provider) || Config.auth_provider() do
      {mod, _prov_opts} when is_atom(mod) -> mod
      mod when is_atom(mod) -> mod
    end
  end

  defp provider_opts(opts) do
    case Keyword.get(opts, :credentials_provider) || Config.auth_provider() do
      {_, prov_opts} -> Keyword.merge(prov_opts, Keyword.get(opts, :credentials_opts, []))
      _ -> Keyword.get(opts, :credentials_opts, [])
    end
  end

  defp maybe_recover_auth(:plex_tv, opts) do
    provider = resolve_provider(opts)
    _ = provider.invalidate(:plex_tv_error, provider_opts(opts))
    :ok
  end

  defp maybe_recover_auth(:pms, opts) do
    provider = resolve_provider(opts)
    _ = provider.invalidate(:pms_error, provider_opts(opts))
    :ok
  end

  defp maybe_retry_on_error(target, method, path_or_url, opts, retries, backoff_base, reason) do
    if retries > 0 do
      sleep(backoff_base, retries)
      do_request(target, method, path_or_url, opts, retries - 1, backoff_base)
    else
      {:error, reason}
    end
  end

  defp sleep(base, retries_left) do
    # exponential backoff with jitter and maximum cap
    attempt = @default_retries - retries_left + 1
    ms = trunc(:math.pow(2, attempt) * base)

    # ✅ Cap maximum backoff at 30 seconds to prevent excessive delays
    max_backoff = 30_000
    capped_ms = min(ms, max_backoff)

    jitter = :rand.uniform(trunc(capped_ms * @backoff_jitter_factor))
    Process.sleep(capped_ms + jitter)
  end
end
