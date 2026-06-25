defmodule MoneyHub.SpendingAnalysisTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.SpendingAnalysis
  alias MoneyHub.Test.StubAdapter

  setup do
    config =
      Config.new!(
        client_id: "c",
        jwk: %{"kty" => "RSA"},
        jwk_kid: "k",
        api_url: "https://api.example.com/v3.0",
        http_options: [adapter: &StubAdapter.call/1]
      )

    {:ok, config: config}
  end

  test "get/3 requires from_date and to_date and forwards them as query params", %{
    config: config
  } do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/spending-analysis"

      assert request.options[:params] == %{
               "fromDate" => "2024-01-01",
               "toDate" => "2024-02-01"
             }

      {request, %Req.Response{status: 200, body: %{"totalSpending" => 1234.5}}}
    end)

    assert {:ok, %{"totalSpending" => 1234.5}} =
             SpendingAnalysis.get(config, "tok", from_date: "2024-01-01", to_date: "2024-02-01")
  end

  test "get/3 forwards optional account_id and category_type", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.options[:params] == %{
               "fromDate" => "2024-01-01",
               "toDate" => "2024-02-01",
               "accountId" => "acc-1",
               "categoryType" => "business"
             }

      {request, %Req.Response{status: 200, body: %{}}}
    end)

    assert {:ok, _} =
             SpendingAnalysis.get(config, "tok",
               from_date: "2024-01-01",
               to_date: "2024-02-01",
               account_id: "acc-1",
               category_type: :business
             )
  end

  test "get/3 raises if from_date is missing", %{config: config} do
    assert_raise KeyError, fn ->
      SpendingAnalysis.get(config, "tok", to_date: "2024-02-01")
    end
  end
end
