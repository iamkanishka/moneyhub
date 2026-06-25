defmodule MoneyHub.PayFile do
  @moduledoc """
  Pay Files: bulk/batch payment submission - initiate many payments from a
  single account in one authorisation, instead of one `MoneyHub.Payments`
  authorisation per payment. Useful for payroll, supplier runs, or refund
  batches.

  Like single payments, creating a pay file is driven through
  `MoneyHub.Auth` (the file contents are submitted alongside the consent
  request), then its progress is tracked by polling or via webhooks.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type pay_file :: map()

  @doc "Fetches a pay file's current status by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, pay_file()} | {:error, Error.t()}
  def get(config, token, pay_file_id) when is_binary(pay_file_id) do
    case Client.request(config, method: :get, path: "/pay-file/#{pay_file_id}", token: token) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists pay files for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [pay_file()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/pay-file", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Lists the individual payment entries within a pay file, with their statuses."
  @spec list_payments(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def list_payments(config, token, pay_file_id) when is_binary(pay_file_id) do
    case Client.request(config,
           method: :get,
           path: "/pay-file/#{pay_file_id}/payments",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end
end
