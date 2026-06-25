defmodule MoneyHub.ConsentHistory do
  @moduledoc """
  Historical record of consent grants/revocations across a user's
  connections and payment authorisations - useful for compliance and audit
  trails.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type consent_event :: map()

  @doc "Lists consent history events for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, [consent_event()]} | {:error, Error.t()}
  def list(config, token, opts \\ []) do
    query =
      %{}
      |> maybe_put("fromDate", Keyword.get(opts, :from_date))
      |> maybe_put("toDate", Keyword.get(opts, :to_date))

    case Client.request(config,
           method: :get,
           path: "/consent-history",
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
