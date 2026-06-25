defmodule MoneyHub.Payees do
  @moduledoc """
  Payee management for payments.

  A payee must generally exist before a payment can be created against it.
  See [Payee Management](https://docs.moneyhubenterprise.com/docs/payee-management)
  and [Payments Overview](https://docs.moneyhubenterprise.com/docs/payments-overview).
  Creating a payee requires the `payee:create` scope.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type payee :: map()

  @doc """
  Creates a payee. `attrs` typically includes `"name"` and an
  `"accountIdentifications"` list (sort code/account number, IBAN, etc).
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) ::
          {:ok, payee()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config, method: :post, path: "/payees", token: token, json: attrs) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists payees for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [payee()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/payees", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single payee by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) :: {:ok, payee()} | {:error, Error.t()}
  def get(config, token, payee_id) when is_binary(payee_id) do
    case Client.request(config, method: :get, path: "/payees/#{payee_id}", token: token) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Deletes a payee."
  @spec delete(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete(config, token, payee_id) when is_binary(payee_id) do
    case Client.request(config, method: :delete, path: "/payees/#{payee_id}", token: token) do
      {:ok, _response} -> :ok
      error -> error
    end
  end
end
