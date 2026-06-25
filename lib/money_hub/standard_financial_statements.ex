defmodule MoneyHub.StandardFinancialStatements do
  @moduledoc """
  Standard Financial Statements (SFS): a pre-filled financial statement
  report, used alongside affordability and income-verification reports in
  lending and collections workflows.

  Like `MoneyHub.Affordability`, report generation is asynchronous:
  `create/3` returns a report in `"pending"` status that later transitions
  to `"complete"` or `"failed"`.

  See [Lending and Collections Widgets](https://docs.moneyhubenterprise.com/docs/lending-and-collection-widgets).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type report :: map()

  @doc "Requests generation of a Standard Financial Statement for the user identified by `token`."
  @spec create(MoneyHub.Config.t(), String.t(), map()) :: {:ok, report()} | {:error, Error.t()}
  def create(config, token, attrs \\ %{}) do
    case Client.request(config,
           method: :post,
           path: "/standard-financial-statements",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists metadata for all Standard Financial Statements for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [report()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config,
           method: :get,
           path: "/standard-financial-statements",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a Standard Financial Statement's current status/contents by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, report()} | {:error, Error.t()}
  def get(config, token, report_id) when is_binary(report_id) do
    case Client.request(config,
           method: :get,
           path: "/standard-financial-statements/#{report_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end
end
