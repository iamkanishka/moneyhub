defmodule MoneyHub.Auth.JWKS do
  @moduledoc """
  Fetches and caches Moneyhub's public JSON Web Key Set (JWKS).

  Moneyhub publishes its signing keys at `{identity_url}/oidc/certs`. These
  keys are used to verify the `id_token` returned from the token endpoint
  (see `MoneyHub.Auth.IdToken`) and to verify webhook payloads signed as
  JWTs (see `MoneyHub.Webhooks`).

  Fetched key sets are cached in-process (an `:persistent_term` per
  `identity_url`) for `:ttl` (default 1 hour) to avoid a network round trip
  on every verification. Call `refresh/1` to force a re-fetch, for example
  after a `kid`-not-found verification failure (key rotation).
  """

  alias MoneyHub.Error

  @default_ttl_ms :timer.hours(1)

  @doc """
  Returns the JWKS for the given `identity_url`, fetching and caching it on
  first use or after expiry.

  ## Options

    * `:ttl` - cache lifetime in milliseconds. Defaults to 1 hour.
    * `:finch_pool` - the Finch pool to issue the fetch through.
    * `:http_options` - extra options merged into the `Req` call (e.g. a
      test `:adapter`).
  """
  @spec fetch(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def fetch(identity_url, opts \\ []) when is_binary(identity_url) do
    key = cache_key(identity_url)

    case :persistent_term.get(key, :not_found) do
      {jwks, expires_at} ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, jwks}
        else
          refresh(identity_url, opts)
        end

      :not_found ->
        refresh(identity_url, opts)
    end
  end

  @doc """
  Forces a re-fetch of the JWKS for `identity_url`, updating the cache.

  Accepts the same `:ttl`, `:finch_pool`, and `:http_options` as `fetch/2`.
  """
  @spec refresh(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def refresh(identity_url, opts \\ []) when is_binary(identity_url) do
    ttl = Keyword.get(opts, :ttl, @default_ttl_ms)
    finch_pool = Keyword.get(opts, :finch_pool, MoneyHub.Finch)
    http_options = Keyword.get(opts, :http_options, [])

    url = identity_url <> "/oidc/certs"

    req_opts = Keyword.merge([url: url, finch: finch_pool, retry: false], http_options)

    case Req.get(req_opts) do
      {:ok, %Req.Response{status: 200, body: %{"keys" => _} = jwks}} ->
        expires_at = System.monotonic_time(:millisecond) + ttl
        :persistent_term.put(cache_key(identity_url), {jwks, expires_at})
        {:ok, jwks}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, Error.api_error(status, body)}

      {:error, exception} ->
        {:error, Error.network_error(exception)}
    end
  end

  @doc """
  Finds the JWK matching `kid` within a JWKS map, as returned by `fetch/2`.
  """
  @spec find_key(map(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def find_key(%{"keys" => keys}, kid) when is_binary(kid) do
    case Enum.find(keys, fn key -> key["kid"] == kid end) do
      nil -> {:error, Error.jwt_error("no JWKS key found for kid #{inspect(kid)}")}
      key -> {:ok, key}
    end
  end

  defp cache_key(identity_url), do: {__MODULE__, identity_url}
end
