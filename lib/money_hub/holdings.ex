defmodule MoneyHub.Holdings do
  @moduledoc """
  Investment account holdings, with ISIN code matching against a reference
  database to enrich each holding with identified security details.

  See [ISIN Code Matching](https://docs.moneyhubenterprise.com/docs/isin-code-matching).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type holding :: map()

  @doc "Lists raw holdings for an investment account, as reported by the provider."
  @spec list(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [holding()]} | {:error, Error.t()}
  def list(config, token, account_id) when is_binary(account_id) do
    case Client.request(config,
           method: :get,
           path: "/accounts/#{account_id}/holdings",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc """
  Lists holdings for an investment account enriched with matched ISIN
  codes and identified security metadata, where a match was found.
  """
  @spec list_with_matches(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [holding()]} | {:error, Error.t()}
  def list_with_matches(config, token, account_id) when is_binary(account_id) do
    case Client.request(config,
           method: :get,
           path: "/accounts/#{account_id}/holdings-with-matches",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single holding (with matched ISIN data) by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t(), String.t()) ::
          {:ok, holding()} | {:error, Error.t()}
  def get(config, token, account_id, holding_id)
      when is_binary(account_id) and is_binary(holding_id) do
    case Client.request(config,
           method: :get,
           path: "/accounts/#{account_id}/holdings/#{holding_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end
end
