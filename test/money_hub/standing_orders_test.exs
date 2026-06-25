defmodule MoneyHub.StandingOrdersTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.StandingOrders
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

  test "get/3 fetches a standing order's status", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/standing-orders/so-1"
      {request, %Req.Response{status: 200, body: %{"id" => "so-1", "status" => "ACTIVE"}}}
    end)

    assert {:ok, %{"status" => "ACTIVE"}} = StandingOrders.get(config, "tok", "so-1")
  end

  test "list/2 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "so-1"}]}}}
    end)

    assert {:ok, [%{"id" => "so-1"}]} = StandingOrders.list(config, "tok")
  end

  test "cancel/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = StandingOrders.cancel(config, "tok", "so-1")
  end
end
