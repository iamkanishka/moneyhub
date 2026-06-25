defmodule MoneyHub.ConsentHistoryTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.ConsentHistory
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

  test "list/3 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/consent-history"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"event" => "granted"}]}}}
    end)

    assert {:ok, [%{"event" => "granted"}]} = ConsentHistory.list(config, "tok")
  end

  test "list/3 forwards date range filters", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.options[:params] == %{"fromDate" => "2024-01-01", "toDate" => "2024-02-01"}
      {request, %Req.Response{status: 200, body: %{"data" => []}}}
    end)

    assert {:ok, []} =
             ConsentHistory.list(config, "tok", from_date: "2024-01-01", to_date: "2024-02-01")
  end
end
