defmodule MoneyHub.Discovery do
  @moduledoc """
  OpenID Connect discovery: fetches Moneyhub's published OIDC provider
  metadata (`/oidc/well-known/openid-configuration`) - endpoint URLs,
  supported scopes, signing algorithms, and so on.

  This is a no-auth, no-token endpoint, unlike everything else in this
  library.
  """

  alias MoneyHub.Error

  @doc """
  Fetches the OIDC discovery document for `config.identity_url`.
  """
  @spec get(MoneyHub.Config.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(%MoneyHub.Config{} = config) do
    url = config.identity_url <> "/oidc/well-known/openid-configuration"

    req_opts =
      Keyword.merge([url: url, finch: config.finch_pool, retry: false], config.http_options)

    case Req.get(req_opts) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, Error.api_error(status, body)}

      {:error, exception} ->
        {:error, Error.network_error(exception)}
    end
  end
end
