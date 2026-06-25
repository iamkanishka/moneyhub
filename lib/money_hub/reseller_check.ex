defmodule MoneyHub.ResellerCheck do
  @moduledoc """
  Reseller check: validates a reseller/partner relationship as part of
  certain onboarding flows.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @doc """
  Performs a reseller check. `attrs` carries whatever identifying
  information the check requires.
  """
  @spec check(MoneyHub.Config.t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def check(config, token, attrs) when is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/reseller-check",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end
end
