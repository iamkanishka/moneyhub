defmodule MoneyHub.AuthRequests do
  @moduledoc """
  The Auth Requests API: an alternative to building authorisation URLs
  and Pushed Authorisation Requests by hand (see `MoneyHub.Auth`) - you
  send the desired scope/claims to this endpoint with your
  `client_credentials` token, and Moneyhub returns a ready-to-use
  authorisation URL.

  This trades a little flexibility (you can't customise every OIDC
  parameter) for convenience, and is useful when you'd rather not
  construct the PAR request body or sign request objects by hand.

  See [Auth Requests](https://docs.moneyhubenterprise.com/docs/auth-requests).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type auth_request :: map()

  @doc """
  Creates an auth request, returning a map that includes a hosted
  authorisation `"url"` to redirect the user's browser to.

  `attrs` carries `"scope"` and (optionally) `"claims"` - the same
  semantics as `MoneyHub.Auth.pushed_authorisation_request/2`, just
  expressed as a plain request body rather than builder options.
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) ::
          {:ok, auth_request()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/auth-requests",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists all auth requests created by this API client."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [auth_request()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/auth-requests", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches an auth request's current status by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, auth_request()} | {:error, Error.t()}
  def get(config, token, auth_request_id) when is_binary(auth_request_id) do
    case Client.request(config,
           method: :get,
           path: "/auth-requests/#{auth_request_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Updates an auth request. Requires both `auth_requests:read` and
  `auth_requests:write` scopes.
  """
  @spec update(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, auth_request()} | {:error, Error.t()}
  def update(config, token, auth_request_id, attrs)
      when is_binary(auth_request_id) and is_map(attrs) do
    case Client.request(config,
           method: :patch,
           path: "/auth-requests/#{auth_request_id}",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end
end
