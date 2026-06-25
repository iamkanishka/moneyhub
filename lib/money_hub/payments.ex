defmodule MoneyHub.Payments do
  @moduledoc """
  Single Immediate Payments (SIP): initiate a payment authorisation and
  check payment status.

  Creating a payment is a two-step process:

  1. Build the payment request payload and drive the user through
     `MoneyHub.Auth` with a `mh:payment` claim (see
     `MoneyHub.Claims.put_payment/2`) and the `payment` scope - the user
     authorises the payment at their bank.
  2. After the redirect back to your `redirect_uri`, exchange the `code`
     via `MoneyHub.Auth.exchange_code/3` and read the resulting payment id
     from the verified `id_token`'s `mh:payment` claim
     (`MoneyHub.Auth.IdToken.fetch/2`).

  Use `status/3` to poll the resulting payment afterwards - Moneyhub
  payments move through `PENDING` -> `COMPLETED` (or `ERROR`/`REJECTED`)
  asynchronously, and are also reported via the `paymentCompleted` /
  `paymentPending` / `paymentError` webhooks (see `MoneyHub.Webhooks`).

  See [Payments Overview](https://docs.moneyhubenterprise.com/docs/payments-overview),
  [Single Immediate Payments](https://docs.moneyhubenterprise.com/docs/single-immediate-payments),
  and [Payments Status](https://docs.moneyhubenterprise.com/docs/payments-status).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type payment :: map()

  @doc """
  Builds the `mh:payment` claim value for a payment authorisation request.

  `attrs` is merged onto required defaults - typically you'll provide at
  least:

      %{
        "amount" => %{"amount" => 10.50, "currency" => "GBP"},
        "creditorAccount" => %{
          "identification" => %{"sortCode" => "010203", "accountNumber" => "12345678"}
        },
        "reference" => "Invoice 123"
      }

  Pass a `"payeeId"` instead of `"creditorAccount"` to pay an existing
  payee created via `MoneyHub.Payees.create/3`.
  """
  @spec build_request(map()) :: map()
  def build_request(attrs) when is_map(attrs), do: attrs

  @doc "Fetches a payment's current status by id."
  @spec status(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, payment()} | {:error, Error.t()}
  def status(config, token, payment_id) when is_binary(payment_id) do
    case Client.request(config, method: :get, path: "/payments/#{payment_id}", token: token) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists payments for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, [payment()]} | {:error, Error.t()}
  def list(config, token, opts \\ []) do
    query = %{} |> maybe_put("status", Keyword.get(opts, :status))

    case Client.request(config, method: :get, path: "/payments", token: token, query: query) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc """
  Initiates a refund of a completed payment, where supported by the
  originating bank. See
  [Reverse Payments](https://docs.moneyhubenterprise.com/docs/reverse-payments).
  """
  @spec refund(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def refund(config, token, payment_id, attrs \\ %{}) when is_binary(payment_id) do
    case Client.request(config,
           method: :post,
           path: "/payments/#{payment_id}/refunds",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
