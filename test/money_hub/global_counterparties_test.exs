defmodule MoneyHub.GlobalCounterpartiesTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.GlobalCounterparties
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
      assert to_string(request.url) =~ "/global-counterparties"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"name" => "Tesco"}]}}}
    end)

    assert {:ok, [%{"name" => "Tesco"}]} = GlobalCounterparties.list(config, "tok")
  end

  test "list/3 forwards query and limit options", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.options[:params] == %{"query" => "Tesco", "limit" => 5}
      {request, %Req.Response{status: 200, body: %{"data" => []}}}
    end)

    assert {:ok, []} = GlobalCounterparties.list(config, "tok", query: "Tesco", limit: 5)
  end
end
