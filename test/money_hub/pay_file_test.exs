defmodule MoneyHub.PayFileTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.PayFile
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
      assert to_string(request.url) =~ "/pay-file"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "pf-1"}]}}}
    end)

    assert {:ok, [%{"id" => "pf-1"}]} = PayFile.list(config, "tok")
  end

  test "get/3 fetches a pay file's status", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/pay-file/pf-1"
      {request, %Req.Response{status: 200, body: %{"id" => "pf-1", "status" => "PROCESSING"}}}
    end)

    assert {:ok, %{"status" => "PROCESSING"}} = PayFile.get(config, "tok", "pf-1")
  end

  test "list_payments/3 lists individual entries in a pay file", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/pay-file/pf-1/payments"

      {request,
       %Req.Response{status: 200, body: %{"data" => [%{"id" => "p1", "status" => "COMPLETED"}]}}}
    end)

    assert {:ok, [%{"status" => "COMPLETED"}]} = PayFile.list_payments(config, "tok", "pf-1")
  end
end
