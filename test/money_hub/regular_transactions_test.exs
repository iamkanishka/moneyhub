defmodule MoneyHub.RegularTransactionsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.RegularTransactions
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

  test "list/3 unwraps the data envelope and forwards account_id", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/regular-transactions"
      assert request.options[:params] == %{"accountId" => "acc-1"}

      {request,
       %Req.Response{
         status: 200,
         body: %{"data" => [%{"id" => "series-1", "description" => "Rent"}]}
       }}
    end)

    assert {:ok, [%{"description" => "Rent"}]} =
             RegularTransactions.list(config, "tok", account_id: "acc-1")
  end

  test "get/3 fetches a single detected series", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/regular-transactions/series-1"
      {request, %Req.Response{status: 200, body: %{"id" => "series-1"}}}
    end)

    assert {:ok, %{"id" => "series-1"}} = RegularTransactions.get(config, "tok", "series-1")
  end
end
