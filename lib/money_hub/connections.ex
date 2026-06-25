defmodule MoneyHub.Connections do
  @moduledoc """
  Connection lifecycle management: listing a user's bank connections,
  checking sync status, and removing connections.

  A "connection" represents one instance of a user linking a single
  financial institution. See
  [Connection Lifecycle](https://docs.moneyhubenterprise.com/docs/connection-lifecycle),
  [Connection Status](https://docs.moneyhubenterprise.com/docs/connection-status),
  and [Connections Management](https://docs.moneyhubenterprise.com/docs/connections-management).

  To *create* a connection, drive the user through `MoneyHub.Auth` with
  AIS scopes - there is no direct "create connection" API call, since
  establishing a connection requires user interaction with their bank.
  To *refresh* an existing connection's data, see `MoneyHub.Claims.put_connection_id/2`
  combined with `MoneyHub.Auth`.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type connection :: map()

  @doc "Lists all connections for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [connection()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/connections", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single connection by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, connection()} | {:error, Error.t()}
  def get(config, token, connection_id) when is_binary(connection_id) do
    case Client.request(config,
           method: :get,
           path: "/connections/#{connection_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Fetches the sync status of a connection - useful for polling after
  initiating an asynchronous connection or a refresh.
  """
  @spec status(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def status(config, token, connection_id) when is_binary(connection_id) do
    case Client.request(config,
           method: :get,
           path: "/connections/#{connection_id}/status",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Removes a connection and its associated accounts/transactions."
  @spec delete(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete(config, token, connection_id) when is_binary(connection_id) do
    case Client.request(config,
           method: :delete,
           path: "/connections/#{connection_id}",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end

  @doc """
  Triggers an immediate sync of an existing connection, refreshing its
  accounts/transactions outside of Moneyhub's normal background schedule.
  Requires `accounts:read` plus either `accounts:write` or
  `accounts:write:all`.
  """
  @spec sync(MoneyHub.Config.t(), String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def sync(config, token, connection_id) when is_binary(connection_id) do
    case Client.request(config, method: :post, path: "/sync/#{connection_id}", token: token) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Lists connections available to be made (bank/provider catalog), without
  requiring a user token - this is a client-credentials-only endpoint.

  See [Available Connections](https://docs.moneyhubenterprise.com/docs/available-connections).
  """
  @spec available(MoneyHub.Config.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def available(config, token) do
    case Client.request(config,
           method: :get,
           path: "/oidc/well-known/all-connections",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Lists only API-based (live, non-screen-scraping) connections."
  @spec available_api(MoneyHub.Config.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def available_api(config, token) do
    case Client.request(config,
           method: :get,
           path: "/oidc/well-known/api-connections",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Lists only legacy (screen-scraping) connections."
  @spec available_legacy(MoneyHub.Config.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def available_legacy(config, token) do
    case Client.request(config,
           method: :get,
           path: "/oidc/well-known/legacy-connections",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Lists only connections that support payment initiation (PIS)."
  @spec available_payments(MoneyHub.Config.t(), String.t()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def available_payments(config, token) do
    case Client.request(config,
           method: :get,
           path: "/oidc/well-known/payments-connections",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Lists only test/mock connections, for use in sandbox development."
  @spec available_test(MoneyHub.Config.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def available_test(config, token) do
    case Client.request(config,
           method: :get,
           path: "/oidc/well-known/test-connections",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end
end
