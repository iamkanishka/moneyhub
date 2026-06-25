defmodule MoneyHub.Counterparties do
  @moduledoc """
  Counterparty data: the merchant/payee/payer identified behind a
  transaction, including logos, categories, and an explicit "is this a
  recognised business" check.

  See [Counterparties](https://docs.moneyhubenterprise.com/docs/counterparties)
  and [Counterparties Check](https://docs.moneyhubenterprise.com/docs/counterparties-check).
  This wraps the V3 counterparties API (V2 is deprecated by Moneyhub).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type counterparty :: map()

  @doc "Lists known counterparties for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, [counterparty()]} | {:error, Error.t()}
  def list(config, token, opts \\ []) do
    query = %{} |> maybe_put("limit", Keyword.get(opts, :limit))

    case Client.request(config,
           method: :get,
           path: "/counterparties",
           token: token,
           query: query
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single counterparty by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, counterparty()} | {:error, Error.t()}
  def get(config, token, counterparty_id) when is_binary(counterparty_id) do
    case Client.request(config,
           method: :get,
           path: "/counterparties/#{counterparty_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Checks whether a free-text name/identifier corresponds to a recognised
  counterparty/business - useful for validating a payee name before
  creating a payment.
  """
  @spec check(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def check(config, token, name) when is_binary(name) do
    case Client.request(config,
           method: :get,
           path: "/counterparties-check",
           token: token,
           query: %{"name" => name}
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
