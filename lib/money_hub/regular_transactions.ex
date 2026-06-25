defmodule MoneyHub.RegularTransactions do
  @moduledoc """
  Regular transaction series detection: recurring payments (subscriptions,
  rent, salary) automatically identified from transaction history.

  See [Regular Transaction Series](https://docs.moneyhubenterprise.com/docs/regular-transaction-series)
  and [Regular Transaction Webhooks](https://docs.moneyhubenterprise.com/docs/regular-transaction-webhooks).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type series :: map()

  @doc """
  Lists detected regular transaction series for the user identified by
  `token`.

  ## Options

    * `:account_id` - filter to a single account.
  """
  @spec list(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, [series()]} | {:error, Error.t()}
  def list(config, token, opts \\ []) do
    query = %{} |> maybe_put("accountId", Keyword.get(opts, :account_id))

    case Client.request(config,
           method: :get,
           path: "/regular-transactions",
           token: token,
           query: query
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single detected series by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, series()} | {:error, Error.t()}
  def get(config, token, series_id) when is_binary(series_id) do
    case Client.request(config,
           method: :get,
           path: "/regular-transactions/#{series_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
