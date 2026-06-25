defmodule MoneyHub.Users do
  @moduledoc """
  Moneyhub user management, for the "ongoing access" integration pattern
  where you maintain a long-lived mapping between your own user records
  and a Moneyhub `sub`.

  In the simplest flow, you never call this module directly: registering a
  user happens implicitly the first time they complete an AIS connection
  via `MoneyHub.Auth.pushed_authorisation_request/2` with
  `MoneyHub.Claims.put_sub/2` called with no fixed id, and Moneyhub assigns
  the `sub` you read back from the `id_token`. This module exists for
  direct user CRUD when you need it (e.g. pre-creating a user record
  before any connection exists).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type user :: map()

  @doc "Fetches a user's record."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) :: {:ok, user()} | {:error, Error.t()}
  def get(config, token, user_id) when is_binary(user_id) do
    case Client.request(config, method: :get, path: "/users/#{user_id}", token: token) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Deletes a user and all of their associated data."
  @spec delete(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete(config, token, user_id) when is_binary(user_id) do
    case Client.request(config, method: :delete, path: "/users/#{user_id}", token: token) do
      {:ok, _response} -> :ok
      error -> error
    end
  end

  @doc """
  Lists a specific user's connections. Equivalent to
  `MoneyHub.Connections.list/2` called with a token scoped to that user via
  `MoneyHub.Auth.token_for_user/3`, but addressable directly by user id
  with a client-credentials-level token.
  """
  @spec list_connections(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def list_connections(config, token, user_id) when is_binary(user_id) do
    case Client.request(config,
           method: :get,
           path: "/users/#{user_id}/connections",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches one of a user's connections by id."
  @spec get_connection(MoneyHub.Config.t(), String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def get_connection(config, token, user_id, connection_id)
      when is_binary(user_id) and is_binary(connection_id) do
    case Client.request(config,
           method: :get,
           path: "/users/#{user_id}/connections/#{connection_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Removes one of a user's connections."
  @spec delete_connection(MoneyHub.Config.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, Error.t()}
  def delete_connection(config, token, user_id, connection_id)
      when is_binary(user_id) and is_binary(connection_id) do
    case Client.request(config,
           method: :delete,
           path: "/users/#{user_id}/connections/#{connection_id}",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end

  @doc "Lists sync status/metadata for all of a user's connections."
  @spec list_syncs(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def list_syncs(config, token, user_id) when is_binary(user_id) do
    case Client.request(config, method: :get, path: "/users/#{user_id}/syncs", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end
end
