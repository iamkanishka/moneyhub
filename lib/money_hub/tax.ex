defmodule MoneyHub.Tax do
  @moduledoc """
  Tax reporting data: transactions surfaced to help answer SA105 (the UK
  Self Assessment questions for property income) for HMRC reporting.

  See [Tax Return](https://docs.moneyhubenterprise.com/docs/tax-return).
  Requires the `tax:read` scope.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @doc """
  Fetches SA105-relevant transaction data for the user identified by
  `token`.

  ## Options

    * `:from_date` / `:to_date` - restrict to a tax year or other date range.
  """
  @spec get(MoneyHub.Config.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(config, token, opts \\ []) do
    query =
      %{}
      |> maybe_put("fromDate", Keyword.get(opts, :from_date))
      |> maybe_put("toDate", Keyword.get(opts, :to_date))

    case Client.request(config, method: :get, path: "/tax", token: token, query: query) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
