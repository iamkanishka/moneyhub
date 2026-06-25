defmodule MoneyHub.ConnectionsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Connections
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
      assert to_string(request.url) =~ "/connections"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "con-1"}]}}}
    end)

    assert {:ok, [%{"id" => "con-1"}]} = Connections.list(config, "tok")
  end

  test "get/3 fetches a single connection", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/connections/con-1"
      {request, %Req.Response{status: 200, body: %{"id" => "con-1"}}}
    end)

    assert {:ok, %{"id" => "con-1"}} = Connections.get(config, "tok", "con-1")
  end

  test "status/3 fetches sync status", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/connections/con-1/status"
      {request, %Req.Response{status: 200, body: %{"status" => "syncing"}}}
    end)

    assert {:ok, %{"status" => "syncing"}} = Connections.status(config, "tok", "con-1")
  end

  test "delete/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = Connections.delete(config, "tok", "con-1")
  end

  test "available/2 fetches the provider catalog", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/oidc/well-known/all-connections"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"name" => "Barclays"}]}}}
    end)

    assert {:ok, [%{"name" => "Barclays"}]} = Connections.available(config, "tok")
  end

  test "sync/3 triggers an immediate sync", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :post
      assert to_string(request.url) =~ "/sync/con-1"
      {request, %Req.Response{status: 202, body: %{"status" => "syncing"}}}
    end)

    assert {:ok, %{"status" => "syncing"}} = Connections.sync(config, "tok", "con-1")
  end

  test "available_api/2 fetches only API-based connections", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/oidc/well-known/api-connections"
      {request, %Req.Response{status: 200, body: %{"data" => []}}}
    end)

    assert {:ok, []} = Connections.available_api(config, "tok")
  end

  test "available_legacy/2 fetches only legacy connections", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/oidc/well-known/legacy-connections"
      {request, %Req.Response{status: 200, body: %{"data" => []}}}
    end)

    assert {:ok, []} = Connections.available_legacy(config, "tok")
  end

  test "available_payments/2 fetches only PIS-capable connections", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/oidc/well-known/payments-connections"
      {request, %Req.Response{status: 200, body: %{"data" => []}}}
    end)

    assert {:ok, []} = Connections.available_payments(config, "tok")
  end

  test "available_test/2 fetches only test/mock connections", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/oidc/well-known/test-connections"
      {request, %Req.Response{status: 200, body: %{"data" => []}}}
    end)

    assert {:ok, []} = Connections.available_test(config, "tok")
  end
end
