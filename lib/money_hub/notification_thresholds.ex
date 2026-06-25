defmodule MoneyHub.NotificationThresholds do
  @moduledoc """
  Balance notification thresholds on an account - configure a balance
  level which, when crossed, triggers the `balanceThreshold` webhook (see
  `MoneyHub.Webhooks`). Used for low-balance alerts and patterns like
  "Smart Saver" VRP sweeping.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type threshold :: map()

  @doc "Lists notification thresholds configured for an account."
  @spec list(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [threshold()]} | {:error, Error.t()}
  def list(config, token, account_id) when is_binary(account_id) do
    case Client.request(config,
           method: :get,
           path: "/accounts/#{account_id}/notification-thresholds",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc """
  Adds a notification threshold to an account. `attrs` typically includes
  the threshold `"amount"` and direction (e.g. below/above).
  """
  @spec create(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, threshold()} | {:error, Error.t()}
  def create(config, token, account_id, attrs)
      when is_binary(account_id) and is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/accounts/#{account_id}/notification-thresholds",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Updates a notification threshold's attributes."
  @spec update(MoneyHub.Config.t(), String.t(), String.t(), String.t(), map()) ::
          {:ok, threshold()} | {:error, Error.t()}
  def update(config, token, account_id, threshold_id, attrs)
      when is_binary(account_id) and is_binary(threshold_id) and is_map(attrs) do
    case Client.request(config,
           method: :patch,
           path: "/accounts/#{account_id}/notification-thresholds/#{threshold_id}",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Deletes a notification threshold."
  @spec delete(MoneyHub.Config.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, Error.t()}
  def delete(config, token, account_id, threshold_id)
      when is_binary(account_id) and is_binary(threshold_id) do
    case Client.request(config,
           method: :delete,
           path: "/accounts/#{account_id}/notification-thresholds/#{threshold_id}",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end
end
