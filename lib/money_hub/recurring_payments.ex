defmodule MoneyHub.RecurringPayments do
  @moduledoc """
  Variable Recurring Payments (VRP): set up a recurring payment consent
  once, then trigger individual payments ("sweeps") against it without
  further user interaction, up to the consented limits.

  Setup mirrors single payments: drive the user through `MoneyHub.Auth`
  with a `mh:recurring_payment` claim (`MoneyHub.Claims.put_recurring_payment/2`)
  and the `recurring_payment` scope. The resulting consent enforces limits
  such as `maximumIndividualAmount` and a periodic cap - individual sweep
  payments must stay within them.

  A common pattern (see Moneyhub's "Smart Saver" recipe) is to combine
  this with `MoneyHub.Webhooks` `balanceThreshold` events: when a
  current-account balance crosses a configured threshold, trigger a sweep
  of the surplus into a savings account.

  See [Recurring Payments (VRP)](https://docs.moneyhubenterprise.com/docs/recurring-payments-vrp).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type consent :: map()
  @type sweep :: map()

  @doc "Lists recurring payment consents created by this API client."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [consent()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/recurring-payments", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a recurring payment consent's current status by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, consent()} | {:error, Error.t()}
  def get(config, token, consent_id) when is_binary(consent_id) do
    case Client.request(config,
           method: :get,
           path: "/recurring-payments/#{consent_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Triggers a single sweep payment against an established VRP consent.

  `attrs` carries the sweep's amount/reference, similar to a single
  payment request - it must stay within the consent's configured limits
  or the bank will reject it. Requires the `recurring-payment:create`
  scope.
  """
  @spec sweep(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, sweep()} | {:error, Error.t()}
  def sweep(config, token, consent_id, attrs) when is_binary(consent_id) and is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/recurring-payments/#{consent_id}/pay",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Checks whether sufficient funds are currently available for a sweep,
  without actually creating a payment. Requires the
  `recurring-payment:funds_confirmation` scope.
  """
  @spec confirm_funds(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def confirm_funds(config, token, consent_id, attrs)
      when is_binary(consent_id) and is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/recurring-payments/#{consent_id}/funds-confirmation",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Revokes a recurring payment consent, preventing further sweeps."
  @spec revoke(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def revoke(config, token, consent_id) when is_binary(consent_id) do
    case Client.request(config,
           method: :delete,
           path: "/recurring-payments/#{consent_id}",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end
end
