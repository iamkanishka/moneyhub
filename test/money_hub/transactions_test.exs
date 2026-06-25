defmodule MoneyHub.TransactionsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Test.StubAdapter
  alias MoneyHub.Transactions

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

  test "list/3 unwraps the data envelope and forwards filters", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.options[:params] == %{
               "accountId" => "acc-1",
               "fromDate" => "2024-01-01",
               "toDate" => "2024-02-01",
               "category" => "groceries",
               "limit" => 10,
               "offset" => 0
             }

      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "t1"}]}}}
    end)

    assert {:ok, [%{"id" => "t1"}]} =
             Transactions.list(config, "tok",
               account_id: "acc-1",
               from_date: "2024-01-01",
               to_date: "2024-02-01",
               category: "groceries",
               limit: 10,
               offset: 0
             )
  end

  test "get/3 fetches a single transaction", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/transactions/t1"
      {request, %Req.Response{status: 200, body: %{"id" => "t1"}}}
    end)

    assert {:ok, %{"id" => "t1"}} = Transactions.get(config, "tok", "t1")
  end

  test "update_category/4 patches the category field", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :patch
      assert request.options[:json] == %{"category" => "cat-2"}
      {request, %Req.Response{status: 200, body: %{"id" => "t1", "category" => "cat-2"}}}
    end)

    assert {:ok, %{"category" => "cat-2"}} =
             Transactions.update_category(config, "tok", "t1", "cat-2")
  end

  test "split/4 posts a list of splits", %{config: config} do
    splits = [%{"amount" => 5.0, "category" => "a"}, %{"amount" => 5.0, "category" => "b"}]

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/transactions/t1/splits"
      assert request.options[:json] == %{"splits" => splits}
      {request, %Req.Response{status: 200, body: %{"id" => "t1", "splits" => splits}}}
    end)

    assert {:ok, %{"splits" => ^splits}} = Transactions.split(config, "tok", "t1", splits)
  end

  test "create/3 posts a single manual transaction", %{config: config} do
    attrs = %{"accountId" => "acc-1", "amount" => -12.5, "description" => "Coffee"}

    StubAdapter.expect(fn request ->
      assert request.method == :post
      assert to_string(request.url) =~ "/transactions"
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "t-new"}}}
    end)

    assert {:ok, %{"id" => "t-new"}} = Transactions.create(config, "tok", attrs)
  end

  test "create_many/3 posts multiple manual transactions and unwraps the data envelope", %{
    config: config
  } do
    transactions = [
      %{"accountId" => "acc-1", "amount" => -5.0, "description" => "Tea"},
      %{"accountId" => "acc-1", "amount" => -7.0, "description" => "Biscuits"}
    ]

    StubAdapter.expect(fn request ->
      assert request.options[:json] == %{"transactions" => transactions}

      {request, %Req.Response{status: 201, body: %{"data" => [%{"id" => "t1"}, %{"id" => "t2"}]}}}
    end)

    assert {:ok, [%{"id" => "t1"}, %{"id" => "t2"}]} =
             Transactions.create_many(config, "tok", transactions)
  end

  test "update/4 patches arbitrary attributes", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :patch
      assert request.options[:json] == %{"description" => "Corrected"}
      {request, %Req.Response{status: 200, body: %{"id" => "t1", "description" => "Corrected"}}}
    end)

    assert {:ok, %{"description" => "Corrected"}} =
             Transactions.update(config, "tok", "t1", %{"description" => "Corrected"})
  end

  test "delete/3 removes a manual transaction", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      assert to_string(request.url) =~ "/transactions/t1"
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = Transactions.delete(config, "tok", "t1")
  end

  test "list_splits/3 fetches current splits", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :get
      assert to_string(request.url) =~ "/transactions/t1/splits"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"amount" => 5.0}]}}}
    end)

    assert {:ok, [%{"amount" => 5.0}]} = Transactions.list_splits(config, "tok", "t1")
  end

  test "update_splits/4 replaces splits via PATCH", %{config: config} do
    splits = [%{"amount" => 10.0, "category" => "a"}]

    StubAdapter.expect(fn request ->
      assert request.method == :patch
      assert to_string(request.url) =~ "/transactions/t1/splits"
      assert request.options[:json] == %{"splits" => splits}
      {request, %Req.Response{status: 200, body: %{"id" => "t1", "splits" => splits}}}
    end)

    assert {:ok, %{"splits" => ^splits}} = Transactions.update_splits(config, "tok", "t1", splits)
  end

  test "delete_splits/3 removes all splits", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      assert to_string(request.url) =~ "/transactions/t1/splits"
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = Transactions.delete_splits(config, "tok", "t1")
  end

  test "list_files/3 lists file attachments", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/transactions/t1/files"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "file-1"}]}}}
    end)

    assert {:ok, [%{"id" => "file-1"}]} = Transactions.list_files(config, "tok", "t1")
  end
end
