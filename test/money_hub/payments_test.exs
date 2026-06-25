defmodule MoneyHub.PaymentsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Payments
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

  test "build_request/1 passes attrs through unchanged" do
    attrs = %{"amount" => %{"amount" => 10.5, "currency" => "GBP"}}
    assert Payments.build_request(attrs) == attrs
  end

  test "status/3 fetches a payment by id", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/payments/pay-1"
      {request, %Req.Response{status: 200, body: %{"id" => "pay-1", "status" => "COMPLETED"}}}
    end)

    assert {:ok, %{"status" => "COMPLETED"}} = Payments.status(config, "tok", "pay-1")
  end

  test "list/3 unwraps the data envelope and forwards a status filter", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/payments"
      assert request.options[:params] == %{"status" => "PENDING"}
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "pay-1"}]}}}
    end)

    assert {:ok, [%{"id" => "pay-1"}]} = Payments.list(config, "tok", status: "PENDING")
  end

  test "refund/4 posts a refund request defaulting attrs to %{}", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/payments/pay-1/refunds"
      assert request.options[:json] == %{}
      {request, %Req.Response{status: 201, body: %{"id" => "refund-1"}}}
    end)

    assert {:ok, %{"id" => "refund-1"}} = Payments.refund(config, "tok", "pay-1")
  end

  test "propagates errors", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 404, body: %{"error" => "NOT_FOUND"}}}
    end)

    assert {:error, error} = Payments.status(config, "tok", "missing")
    assert error.status == 404
  end
end
