defmodule MoneyHub.PayeesTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Payees
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

  test "create/3 posts a payee", %{config: config} do
    attrs = %{
      "name" => "Jane Doe",
      "accountIdentifications" => [%{"sortCode" => "010203", "accountNumber" => "12345678"}]
    }

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/payees"
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "payee-1"}}}
    end)

    assert {:ok, %{"id" => "payee-1"}} = Payees.create(config, "tok", attrs)
  end

  test "list/2 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "payee-1"}]}}}
    end)

    assert {:ok, [%{"id" => "payee-1"}]} = Payees.list(config, "tok")
  end

  test "get/3 fetches a payee", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/payees/payee-1"
      {request, %Req.Response{status: 200, body: %{"id" => "payee-1"}}}
    end)

    assert {:ok, %{"id" => "payee-1"}} = Payees.get(config, "tok", "payee-1")
  end

  test "delete/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = Payees.delete(config, "tok", "payee-1")
  end
end
