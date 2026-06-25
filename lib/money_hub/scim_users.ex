defmodule MoneyHub.ScimUsers do
  @moduledoc """
  SCIM users: a [SCIM](https://en.wikipedia.org/wiki/System_for_Cross-domain_Identity_Management)-style
  user identity resource that can hold personally identifiable information
  (name, email, etc), as distinct from `MoneyHub.Users` (the lightweight
  data-only user record `sub` claims point at).

  Used primarily for embedded-component (widget) tenant user provisioning -
  see [Creating Users and Token Generation](https://docs.moneyhubenterprise.com/docs/creating-users-and-token-generation).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type scim_user :: map()

  @doc "Lists SCIM users for this API client/tenant."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [scim_user()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/scim-users", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc """
  Creates a SCIM user. `attrs` follows the SCIM user schema (e.g.
  `"userName"`, `"name"`, `"emails"`).
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) ::
          {:ok, scim_user()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config, method: :post, path: "/scim-users", token: token, json: attrs) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Fetches a single SCIM user by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, scim_user()} | {:error, Error.t()}
  def get(config, token, scim_user_id) when is_binary(scim_user_id) do
    case Client.request(config,
           method: :get,
           path: "/scim-users/#{scim_user_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Updates a SCIM user's attributes."
  @spec update(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, scim_user()} | {:error, Error.t()}
  def update(config, token, scim_user_id, attrs)
      when is_binary(scim_user_id) and is_map(attrs) do
    case Client.request(config,
           method: :patch,
           path: "/scim-users/#{scim_user_id}",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Deletes a SCIM user."
  @spec delete(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete(config, token, scim_user_id) when is_binary(scim_user_id) do
    case Client.request(config,
           method: :delete,
           path: "/scim-users/#{scim_user_id}",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end
end
