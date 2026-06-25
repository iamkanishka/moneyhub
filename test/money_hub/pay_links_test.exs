defmodule MoneyHub.PayLinksTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.PayLinks
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

  test "create/3 posts a pay link request and returns a hosted url", %{config: config} do
    attrs = %{"amount" => %{"amount" => 25.0, "currency" => "GBP"}, "reference" => "Invoice 9"}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/pay-links"
      assert request.options[:json] == attrs

      {request,
       %Req.Response{
         status: 201,
         body: %{"id" => "pl-1", "url" => "https://pay.moneyhub.co.uk/pl-1"}
       }}
    end)

    assert {:ok, %{"url" => url}} = PayLinks.create(config, "tok", attrs)
    assert url =~ "pay.moneyhub.co.uk"
  end

  test "get/3 fetches a pay link's status", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/pay-links/pl-1"
      {request, %Req.Response{status: 200, body: %{"id" => "pl-1", "status" => "PAID"}}}
    end)

    assert {:ok, %{"status" => "PAID"}} = PayLinks.get(config, "tok", "pl-1")
  end

  test "cancel/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = PayLinks.cancel(config, "tok", "pl-1")
  end
end
