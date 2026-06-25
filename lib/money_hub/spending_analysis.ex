defmodule MoneyHub.SpendingAnalysis do
  @moduledoc """
  Aggregated spending and income statistics over arbitrary date ranges,
  grouped by category - useful for "this month vs last month" comparisons
  without manually summing transactions client-side.

  See [Spending and Income Analysis](https://docs.moneyhubenterprise.com/docs/spending-and-income-analysis).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @doc """
  Fetches aggregated spending/income stats for the given date range.

  ## Options

    * `:from_date` / `:to_date` - required, ISO 8601 date strings.
    * `:account_id` - restrict the analysis to a single account.
    * `:category_type` - `:personal` (default) or `:business`.
  """
  @spec get(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def get(config, token, opts) do
    from_date = Keyword.fetch!(opts, :from_date)
    to_date = Keyword.fetch!(opts, :to_date)

    query =
      %{"fromDate" => from_date, "toDate" => to_date}
      |> maybe_put("accountId", Keyword.get(opts, :account_id))
      |> maybe_put("categoryType", category_type(Keyword.get(opts, :category_type)))

    case Client.request(config,
           method: :get,
           path: "/spending-analysis",
           token: token,
           query: query
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  defp category_type(nil), do: nil
  defp category_type(type) when is_atom(type), do: Atom.to_string(type)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
