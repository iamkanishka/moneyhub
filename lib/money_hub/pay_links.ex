defmodule MoneyHub.PayLinks do
  @moduledoc """
  Pay Links: shareable, hosted single-payment links that don't require
  embedding a widget yourself - useful for invoicing flows where you just
  need to send a customer a URL.

  See [Pay Link Widget](https://docs.moneyhubenterprise.com/docs/pay-link-widget)
  and [Create Pay Link](https://docs.moneyhubenterprise.com/docs/create-pay-link).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type pay_link :: map()

  @doc """
  Creates a pay link. `attrs` typically includes the amount, currency,
  reference, and the payee (or creditor account) to receive funds. Returns
  a `pay_link` map containing a hosted `"url"` to share with the payer.
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) ::
          {:ok, pay_link()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config, method: :post, path: "/pay-links", token: token, json: attrs) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Fetches a pay link's current status by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, pay_link()} | {:error, Error.t()}
  def get(config, token, pay_link_id) when is_binary(pay_link_id) do
    case Client.request(config, method: :get, path: "/pay-links/#{pay_link_id}", token: token) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Cancels (expires) a pay link before it has been paid."
  @spec cancel(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def cancel(config, token, pay_link_id) when is_binary(pay_link_id) do
    case Client.request(config,
           method: :delete,
           path: "/pay-links/#{pay_link_id}",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end
end
