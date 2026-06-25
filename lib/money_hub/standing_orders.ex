defmodule MoneyHub.StandingOrders do
  @moduledoc """
  Standing order creation and management via Payment Initiation.

  Setup mirrors single payments: drive the user through `MoneyHub.Auth`
  with a `mh:standing_order` claim (`MoneyHub.Claims.put_standing_order/2`)
  and the `standing_order` scope, specifying frequency, start date, and
  optionally an end date or number of payments.

  See [Standing Order Requests](https://docs.moneyhubenterprise.com/docs/standing-order-requests)
  and [Standing Order Retrieve](https://docs.moneyhubenterprise.com/docs/standing-order-retrieve).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type standing_order :: map()

  @doc "Fetches a standing order's current status by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, standing_order()} | {:error, Error.t()}
  def get(config, token, standing_order_id) when is_binary(standing_order_id) do
    case Client.request(config,
           method: :get,
           path: "/standing-orders/#{standing_order_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists standing orders for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t()) ::
          {:ok, [standing_order()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/standing-orders", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Cancels a standing order."
  @spec cancel(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def cancel(config, token, standing_order_id) when is_binary(standing_order_id) do
    case Client.request(config,
           method: :delete,
           path: "/standing-orders/#{standing_order_id}",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end
end
