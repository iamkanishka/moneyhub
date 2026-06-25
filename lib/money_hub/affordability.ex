defmodule MoneyHub.Affordability do
  @moduledoc """
  Affordability and income verification reports, and Standard Financial
  Statements - used in lending and collections workflows.

  Report generation is asynchronous: `create/3` returns a report in
  `"pending"` status, which transitions to `"complete"` (or `"failed"`)
  some time later. Poll with `get/3`, or subscribe to the
  `affordabilityReportSuccess` / `affordabilityReportFailure` webhooks
  (see `MoneyHub.Webhooks`) instead of polling.

  See [Lending and Collections Reports](https://docs.moneyhubenterprise.com/docs/lending-and-collections-reports)
  and [Creating Affordability Widgets](https://docs.moneyhubenterprise.com/docs/creating-affordability-widgets).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type report :: map()

  @doc """
  Requests generation of an affordability (or income verification) report
  for the user identified by `token`. `attrs` selects the report type and
  any configuration (e.g. which accounts/date range to include).
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) :: {:ok, report()} | {:error, Error.t()}
  def create(config, token, attrs \\ %{}) do
    case Client.request(config,
           method: :post,
           path: "/affordability-reports",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Fetches a report's current status/contents by id. While `"status"` is
  `"pending"`, the report body is not yet populated.
  """
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, report()} | {:error, Error.t()}
  def get(config, token, report_id) when is_binary(report_id) do
    case Client.request(config,
           method: :get,
           path: "/affordability-reports/#{report_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Polls `get/3` until the report's status leaves `"pending"`, sleeping
  `interval_ms` between attempts, up to `max_attempts`. Returns the final
  report (whether `"complete"` or `"failed"`) or an error if the request
  itself fails or attempts are exhausted while still pending.

  Prefer subscribing to the `affordabilityReportSuccess` /
  `affordabilityReportFailure` webhooks in production - this helper is
  intended for scripts, tests, and simple synchronous workflows.
  """
  @spec await(MoneyHub.Config.t(), String.t(), String.t(), keyword()) ::
          {:ok, report()} | {:error, Error.t()}
  def await(config, token, report_id, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 30)
    interval_ms = Keyword.get(opts, :interval_ms, 2_000)
    do_await(config, token, report_id, max_attempts, interval_ms)
  end

  defp do_await(_config, _token, _report_id, 0, _interval_ms) do
    {:error, Error.validation_error("affordability report still pending after max attempts")}
  end

  defp do_await(config, token, report_id, attempts_left, interval_ms) do
    case get(config, token, report_id) do
      {:ok, %{"status" => "pending"}} ->
        Process.sleep(interval_ms)
        do_await(config, token, report_id, attempts_left - 1, interval_ms)

      {:ok, report} ->
        {:ok, report}

      error ->
        error
    end
  end
end
