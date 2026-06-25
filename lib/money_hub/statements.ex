defmodule MoneyHub.Statements do
  @moduledoc """
  Account statements - periodic statement documents/metadata for a
  connected account, where the provider exposes them.

  Reading statements requires `accounts:read` plus either
  `statements_basic:read` or `statements_detail:read`, depending on the
  level of detail needed.

  See [Statements](https://docs.moneyhubenterprise.com/docs/statements).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type statement :: map()

  @doc "Lists statements available for an account."
  @spec list(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [statement()]} | {:error, Error.t()}
  def list(config, token, account_id) when is_binary(account_id) do
    case Client.request(config,
           method: :get,
           path: "/accounts/#{account_id}/statements",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end
end
