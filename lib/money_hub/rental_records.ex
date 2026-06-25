defmodule MoneyHub.RentalRecords do
  @moduledoc """
  Rental payment record submission - reporting a tenant's verified rent
  payment history (typically derived from detected regular transactions)
  to a credit reference agency such as Experian, to help build their
  credit file.

  Submitting a rental record requires separate user consent beyond the AIS
  connection - see
  [Rental Recognition](https://docs.moneyhubenterprise.com/docs/rental-recognition)
  for the two-consent flow.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type rental_record :: map()

  @doc """
  Creates a rental record. `attrs` typically includes the tenancy details
  (landlord/letting agent, address, monthly rent amount) and references
  the verified regular transaction series for the rent payments.
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) ::
          {:ok, rental_record()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/rental-records",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Fetches a rental record's status by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, rental_record()} | {:error, Error.t()}
  def get(config, token, rental_record_id) when is_binary(rental_record_id) do
    case Client.request(config,
           method: :get,
           path: "/rental-records/#{rental_record_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end
end
