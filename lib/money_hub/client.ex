defmodule MoneyHub.Client do
  @moduledoc """
  Low-level HTTP client for the Moneyhub data API (`api_url`).

  Every resource module (`MoneyHub.Accounts`, `MoneyHub.Transactions`,
  `MoneyHub.Payments`, ...) delegates its HTTP calls through here, so
  retry behaviour, rate-limit handling, and error normalisation are
  implemented exactly once.

  You generally won't call this module directly - use the resource modules
  instead. It's part of the public API for advanced use cases (calling
  endpoints not yet wrapped by a dedicated module) via `request/2`.

  ## Retries

  Moneyhub's rate limit (per their docs) is approximately 1000 requests per
  minute per client, returning `429` with a `Retry-After` header when
  exceeded. `request/2` retries `429` responses automatically (honouring
  `Retry-After`, capped by `:max_retry_after_ms`) and retries `5xx`/network
  errors with capped exponential backoff, up to `:max_retries` (default 2).

  Emits `[:money_hub, :request, :start | :stop | :exception]` telemetry
  events around every call.
  """

  alias MoneyHub.Error

  @default_max_retries 2
  @default_max_retry_after_ms :timer.seconds(30)
  @default_timeout :timer.seconds(60)

  @type method :: :get | :post | :patch | :put | :delete
  @type token :: String.t()

  @doc """
  Issues an HTTP request against the data API.

  ## Options

    * `:method` - required, one of `:get`, `:post`, `:patch`, `:put`,
      `:delete`.
    * `:path` - required, relative to `config.api_url`, e.g. `"/accounts"`.
    * `:token` - required, a bearer access token.
    * `:query` - a map/keyword list of query parameters.
    * `:json` - a request body to be JSON-encoded.
    * `:max_retries` - overrides the default retry count.
    * `:max_retry_after_ms` - caps how long a `Retry-After` driven sleep
      may be, to bound worst-case latency.
  """
  @spec request(MoneyHub.Config.t(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, Error.t()}
  def request(%MoneyHub.Config{} = config, opts) do
    method = Keyword.fetch!(opts, :method)
    path = Keyword.fetch!(opts, :path)
    token = Keyword.fetch!(opts, :token)

    metadata = %{method: method, path: path}

    :telemetry.span([:money_hub, :request], metadata, fn ->
      result = do_request(config, method, path, token, opts, 0)
      {result, Map.put(metadata, :result, request_result_tag(result))}
    end)
  end

  defp request_result_tag({:ok, %Req.Response{status: status}}), do: status
  defp request_result_tag({:error, %Error{reason: reason}}), do: reason

  # defp do_request(config, method, path, token, opts, attempt) do
  #   url = config.api_url <> path
  #   query = Keyword.get(opts, :query)
  #   json = Keyword.get(opts, :json)
  #   max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
  #   max_retry_after_ms = Keyword.get(opts, :max_retry_after_ms, @default_max_retry_after_ms)

  #   req_opts =
  #     Keyword.merge(
  #       [
  #         method: method,
  #         url: url,
  #         headers: [{"authorization", "Bearer " <> token}],
  #         finch: config.finch_pool,
  #         receive_timeout: @default_timeout,
  #         retry: false
  #       ],
  #       config.http_options
  #     )

  #   req_opts = if query, do: Keyword.put(req_opts, :params, query), else: req_opts
  #   req_opts = if json, do: Keyword.put(req_opts, :json, json), else: req_opts

  #   case Req.request(req_opts) do
  #     {:ok, %Req.Response{status: status} = response} when status in 200..299 ->
  #       {:ok, response}

  #     {:ok, %Req.Response{status: 429, headers: headers} = response} ->
  #       if attempt < max_retries do
  #         sleep_for_retry_after(headers, max_retry_after_ms)
  #         do_request(config, method, path, token, opts, attempt + 1)
  #       else
  #         {:error, Error.api_error(429, response.body, normalize_headers(headers))}
  #       end

  #     {:ok, %Req.Response{status: status} = response} when status >= 500 ->
  #       if attempt < max_retries do
  #         backoff(attempt)
  #         do_request(config, method, path, token, opts, attempt + 1)
  #       else
  #         {:error, Error.api_error(status, response.body)}
  #       end

  #     {:ok, %Req.Response{status: status, body: body}} ->
  #       {:error, Error.api_error(status, body)}

  #     {:error, exception} ->
  #       if attempt < max_retries do
  #         backoff(attempt)
  #         do_request(config, method, path, token, opts, attempt + 1)
  #       else
  #         {:error, Error.network_error(exception)}
  #       end
  #   end
  # end

  defp do_request(config, method, path, token, opts, attempt) do
    req_opts = build_request(config, method, path, token, opts)

    retry_opts = %{
      max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
      max_retry_after_ms: Keyword.get(opts, :max_retry_after_ms, @default_max_retry_after_ms)
    }

    Req.request(req_opts)
    |> handle_response(config, method, path, token, opts, attempt, retry_opts)
  end

  defp build_request(config, method, path, token, opts) do
    req_opts =
      Keyword.merge(
        [
          method: method,
          url: config.api_url <> path,
          headers: [{"authorization", "Bearer " <> token}],
          finch: config.finch_pool,
          receive_timeout: @default_timeout,
          retry: false
        ],
        config.http_options
      )

    req_opts
    |> maybe_put(:params, Keyword.get(opts, :query))
    |> maybe_put(:json, Keyword.get(opts, :json))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp handle_response(
         {:ok, %Req.Response{status: status} = response},
         _config,
         _method,
         _path,
         _token,
         _opts,
         _attempt,
         _retry_opts
       )
       when status in 200..299 do
    {:ok, response}
  end

  defp handle_response(
         {:ok, %Req.Response{status: 429, headers: headers} = response},
         config,
         method,
         path,
         token,
         opts,
         attempt,
         %{max_retries: max_retries, max_retry_after_ms: max_retry_after_ms}
       ) do
    if attempt < max_retries do
      sleep_for_retry_after(headers, max_retry_after_ms)
      do_request(config, method, path, token, opts, attempt + 1)
    else
      {:error, Error.api_error(429, response.body, normalize_headers(headers))}
    end
  end

  defp handle_response(
         {:ok, %Req.Response{status: status} = response},
         config,
         method,
         path,
         token,
         opts,
         attempt,
         %{max_retries: max_retries}
       )
       when status >= 500 do
    if attempt < max_retries do
      backoff(attempt)
      do_request(config, method, path, token, opts, attempt + 1)
    else
      {:error, Error.api_error(status, response.body)}
    end
  end

  defp handle_response(
         {:ok, %Req.Response{status: status, body: body}},
         _config,
         _method,
         _path,
         _token,
         _opts,
         _attempt,
         _retry_opts
       ) do
    {:error, Error.api_error(status, body)}
  end

  defp handle_response(
         {:error, exception},
         config,
         method,
         path,
         token,
         opts,
         attempt,
         %{max_retries: max_retries}
       ) do
    if attempt < max_retries do
      backoff(attempt)
      do_request(config, method, path, token, opts, attempt + 1)
    else
      {:error, Error.network_error(exception)}
    end
  end

  defp sleep_for_retry_after(headers, max_ms) do
    headers
    |> normalize_headers()
    |> List.keyfind("retry-after", 0)
    |> case do
      {_, value} ->
        case Integer.parse(value) do
          {seconds, _} -> Process.sleep(min(seconds * 1000, max_ms))
          :error -> Process.sleep(min(1000, max_ms))
        end

      nil ->
        Process.sleep(min(1000, max_ms))
    end
  end

  defp backoff(attempt) do
    base = (:math.pow(2, attempt) * 200) |> round()
    jitter = :rand.uniform(100)
    Process.sleep(base + jitter)
  end

  # Req.Response.headers is always a map of binary => [binary] (see
  # Req.Response's typespec) - this only normalizes that shape down to a
  # flat list of {downcased_key, value} string pairs for easy lookup.
  defp normalize_headers(headers) when is_map(headers) do
    headers
    |> Enum.flat_map(fn {k, vs} ->
      Enum.map(List.wrap(vs), &{String.downcase(k), to_string(&1)})
    end)
  end

  @doc """
  Safely unwraps a `%{"data" => [...]}` envelope, as returned by most list
  endpoints, falling back to the raw body unchanged when it isn't a map
  with a `"data"` key (for example if the body is already a bare list).

  Resource modules use this instead of `response.body["data"] || response.body`
  directly, since that pattern raises `ArgumentError` when `response.body`
  is a list (lists only support atom-keyed `Access` calls).
  """
  @spec unwrap_list(term()) :: term()
  def unwrap_list(%{"data" => data}), do: data
  def unwrap_list(body), do: body
end
