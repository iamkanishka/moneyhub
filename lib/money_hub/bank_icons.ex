defmodule MoneyHub.BankIcons do
  @moduledoc """
  Fetches a bank/institution's icon image by its bank reference, for use
  in bank-chooser UIs alongside `MoneyHub.Connections.available/2`.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @doc """
  Fetches the icon for a given bank reference, using a `client_credentials`
  token (the same kind used for `MoneyHub.Connections.available/2`).
  Returns the raw `Req.Response.t()` so callers can inspect `content-type`
  and write the body to a file or stream it back to a client.
  """
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, Req.Response.t()} | {:error, Error.t()}
  def get(config, token, bank_ref) when is_binary(bank_ref) do
    Client.request(config, method: :get, path: "/bank-icons/#{bank_ref}", token: token)
  end
end
