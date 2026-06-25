defmodule MoneyHub.AccountsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Accounts
  alias MoneyHub.Config
  alias MoneyHub.Test.StubAdapter

  setup do
    config =
      Config.new!(
        client_id: "client-abc",
        jwk: %{"kty" => "RSA"},
        jwk_kid: "kid-1",
        api_url: "https://api.example.com/v3.0",
        http_options: [adapter: &StubAdapter.call/1]
      )

    {:ok, config: config}
  end

  test "list/3 fetches /accounts and unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "https://api.example.com/v3.0/accounts"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "acc-1"}]}}}
    end)

    assert {:ok, [%{"id" => "acc-1"}]} = Accounts.list(config, "tok")
  end

  test "list/3 returns the raw body when there is no data envelope", %{config: config} do
    StubAdapter.expect(fn request -> {request, %Req.Response{status: 200, body: []}} end)
    assert {:ok, []} = Accounts.list(config, "tok")
  end

  test "list/3 passes connection_id and account_type as query params", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.options[:params] == %{"connectionId" => "con-1", "accountType" => "cash"}
      {request, %Req.Response{status: 200, body: %{"data" => []}}}
    end)

    assert {:ok, []} = Accounts.list(config, "tok", connection_id: "con-1", account_type: "cash")
  end

  test "get/3 fetches a single account", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) == "https://api.example.com/v3.0/accounts/acc-1"
      {request, %Req.Response{status: 200, body: %{"id" => "acc-1"}}}
    end)

    assert {:ok, %{"id" => "acc-1"}} = Accounts.get(config, "tok", "acc-1")
  end

  test "create/3 posts a manual account payload", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :post
      assert request.options[:json] == %{"type" => "properties:residential"}
      {request, %Req.Response{status: 201, body: %{"id" => "acc-new"}}}
    end)

    assert {:ok, %{"id" => "acc-new"}} =
             Accounts.create(config, "tok", %{"type" => "properties:residential"})
  end

  test "update/4 patches an account", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :patch
      assert request.options[:json] == %{"name" => "New name"}
      {request, %Req.Response{status: 200, body: %{"id" => "acc-1", "name" => "New name"}}}
    end)

    assert {:ok, %{"name" => "New name"}} =
             Accounts.update(config, "tok", "acc-1", %{"name" => "New name"})
  end

  test "delete/3 issues a DELETE and returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = Accounts.delete(config, "tok", "acc-1")
  end

  test "balances/4 fetches historical balances with optional date filters", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "https://api.example.com/v3.0/accounts/acc-1/balances"

      assert request.options[:params] == %{
               "fromDate" => "2024-01-01",
               "toDate" => "2024-02-01"
             }

      {request, %Req.Response{status: 200, body: %{"data" => [%{"amount" => 100}]}}}
    end)

    assert {:ok, [%{"amount" => 100}]} =
             Accounts.balances(config, "tok", "acc-1",
               from_date: "2024-01-01",
               to_date: "2024-02-01"
             )
  end

  test "propagates errors from the underlying client", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 404, body: %{"error" => "NOT_FOUND"}}}
    end)

    assert {:error, error} = Accounts.get(config, "tok", "missing")
    assert error.reason == :api_error
    assert error.status == 404
  end

  test "add_balance/4 posts a new balance entry for a manual account", %{config: config} do
    attrs = %{"amount" => 5000, "date" => "2024-06-01"}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/accounts/acc-1/balances"
      assert request.method == :post
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "bal-1"}}}
    end)

    assert {:ok, %{"id" => "bal-1"}} = Accounts.add_balance(config, "tok", "acc-1", attrs)
  end

  test "standing_orders/3 fetches bank-reported standing orders for an account", %{
    config: config
  } do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/accounts/acc-1/standing-orders"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "so-1"}]}}}
    end)

    assert {:ok, [%{"id" => "so-1"}]} = Accounts.standing_orders(config, "tok", "acc-1")
  end

  test "syncs/2 fetches sync status for all accounts", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/accounts/syncs"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"accountId" => "acc-1"}]}}}
    end)

    assert {:ok, [%{"accountId" => "acc-1"}]} = Accounts.syncs(config, "tok")
  end
end
