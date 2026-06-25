defmodule MoneyHub.Webhooks.Event do
  @moduledoc """
  A parsed, verified Moneyhub webhook event.

  ## Known event ids

  Financial data:

    * `"newTransactions"`, `"updatedTransactions"`, `"deletedTransactions"`,
      `"restoredTransactions"` - transaction lifecycle, each carrying a
      list of transaction ids (capped at 6000 ids per batch).
    * `"deletedAccount"` - an account was removed by the institution.
    * `"syncCompleted"` - a connection's sync cycle finished.
    * `"postConnectionEnrichmentCompleted"` - categorisation/enrichment
      finished after sync.

  Payments:

    * `"paymentCompleted"`, `"paymentPending"`, `"paymentError"`.

  Decisioning:

    * `"affordabilityReportSuccess"`, `"affordabilityReportFailure"`.

  Nudges:

    * `"addFirstConnection"`, `"balanceThreshold"`, `"reauthReminder"`,
      `"refreshReminder"`.

  See the [webhooks introduction](https://docs.moneyhubenterprise.com/docs/webhooks-introduction)
  and the individual event pages linked from it for full payload shapes.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          payload: map(),
          user_id: String.t() | nil,
          connection_id: String.t() | nil,
          raw: map()
        }

  @enforce_keys [:id, :payload, :raw]
  defstruct [:id, :payload, :user_id, :connection_id, :raw]

  @doc false
  @spec from_map(map()) :: t()
  def from_map(%{"id" => id} = raw) do
    %__MODULE__{
      id: id,
      payload: Map.get(raw, "payload", Map.drop(raw, ["id", "userId", "connectionId"])),
      user_id: Map.get(raw, "userId"),
      connection_id: Map.get(raw, "connectionId"),
      raw: raw
    }
  end
end
