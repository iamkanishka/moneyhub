defmodule MoneyHub.GlobalCounterparties do
  @moduledoc """
  Global counterparties: Moneyhub's shared, user-independent reference
  database of known merchants/businesses, as distinct from
  `MoneyHub.Counterparties` (counterparties seen in a specific user's
  transaction history).

  Useful for typeahead/search when building a payee picker, or for
  enriching data without a user-level token.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type counterparty :: map()

  @doc """
  Searches the global counterparty database.

  ## Options

    * `:query` - free-text search term (e.g. a merchant name).
    * `:limit` - maximum number of results.
  """
  @spec list(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, [counterparty()]} | {:error, Error.t()}
  def list(config, token, opts \\ []) do
    query =
      %{}
      |> maybe_put("query", Keyword.get(opts, :query))
      |> maybe_put("limit", Keyword.get(opts, :limit))

    case Client.request(config,
           method: :get,
           path: "/global-counterparties",
           token: token,
           query: query
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
