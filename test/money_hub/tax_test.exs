defmodule MoneyHub.TaxTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Tax
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

  test "get/3 fetches SA105 data with no filters", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/tax"
      {request, %Req.Response{status: 200, body: %{"propertyIncome" => 12_000}}}
    end)

    assert {:ok, %{"propertyIncome" => 12_000}} = Tax.get(config, "tok")
  end

  test "get/3 forwards from_date/to_date filters", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.options[:params] == %{"fromDate" => "2023-04-06", "toDate" => "2024-04-05"}
      {request, %Req.Response{status: 200, body: %{}}}
    end)

    assert {:ok, _} = Tax.get(config, "tok", from_date: "2023-04-06", to_date: "2024-04-05")
  end
end
