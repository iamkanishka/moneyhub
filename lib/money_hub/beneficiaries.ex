defmodule MoneyHub.Beneficiaries do
  @moduledoc """
  Beneficiaries: payees the user has previously sent money to from a
  connected account, as detected from open banking data (distinct from
  `MoneyHub.Payees`, which are payees *you* create for initiating
  payments).

  Reading the postal address and other extended fields requires the
  optional `beneficiaries_detail:read` scope in addition to
  `beneficiaries:read`.

  See [Beneficiaries](https://docs.moneyhubenterprise.com/docs/beneficiaries)
  and [Sensitive Information](https://docs.moneyhubenterprise.com/docs/sensitive-information).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type beneficiary :: map()

  @doc "Lists beneficiaries for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [beneficiary()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/beneficiaries", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single beneficiary by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, beneficiary()} | {:error, Error.t()}
  def get(config, token, beneficiary_id) when is_binary(beneficiary_id) do
    case Client.request(config,
           method: :get,
           path: "/beneficiaries/#{beneficiary_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end
end
