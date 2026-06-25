defmodule MoneyHub.RecurringPaymentsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.RecurringPayments
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

  test "list/2 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/recurring-payments"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "con-1"}]}}}
    end)

    assert {:ok, [%{"id" => "con-1"}]} = RecurringPayments.list(config, "tok")
  end

  test "get/3 fetches a consent's status", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/recurring-payments/con-1"
      {request, %Req.Response{status: 200, body: %{"id" => "con-1", "status" => "AUTHORISED"}}}
    end)

    assert {:ok, %{"status" => "AUTHORISED"}} = RecurringPayments.get(config, "tok", "con-1")
  end

  test "sweep/4 posts to /recurring-payments/{id}/pay against the consent", %{config: config} do
    attrs = %{"amount" => %{"amount" => 50.0, "currency" => "GBP"}}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/recurring-payments/con-1/pay"
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "sweep-1", "status" => "PENDING"}}}
    end)

    assert {:ok, %{"id" => "sweep-1"}} = RecurringPayments.sweep(config, "tok", "con-1", attrs)
  end

  test "confirm_funds/4 checks fund availability without creating a payment", %{config: config} do
    attrs = %{"amount" => %{"amount" => 50.0, "currency" => "GBP"}}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/recurring-payments/con-1/funds-confirmation"
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 200, body: %{"fundsAvailable" => true}}}
    end)

    assert {:ok, %{"fundsAvailable" => true}} =
             RecurringPayments.confirm_funds(config, "tok", "con-1", attrs)
  end

  test "revoke/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      assert to_string(request.url) =~ "/recurring-payments/con-1"
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = RecurringPayments.revoke(config, "tok", "con-1")
  end

  test "sweep/4 surfaces an error when the amount exceeds consent limits", %{config: config} do
    StubAdapter.expect(fn request ->
      {request,
       %Req.Response{
         status: 400,
         body: %{"error" => "AMOUNT_EXCEEDS_LIMIT"}
       }}
    end)

    assert {:error, error} =
             RecurringPayments.sweep(config, "tok", "con-1", %{
               "amount" => %{"amount" => 999_999, "currency" => "GBP"}
             })

    assert error.code == "AMOUNT_EXCEEDS_LIMIT"
  end
end
