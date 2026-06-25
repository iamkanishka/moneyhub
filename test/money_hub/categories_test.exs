defmodule MoneyHub.CategoriesTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Categories
  alias MoneyHub.Config
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

  test "list/3 defaults to :personal category type", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.options[:params] == %{"type" => "personal"}
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "groceries"}]}}}
    end)

    assert {:ok, [%{"id" => "groceries"}]} = Categories.list(config, "tok")
  end

  test "list/3 accepts :type :business", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.options[:params] == %{"type" => "business"}
      {request, %Req.Response{status: 200, body: %{"data" => []}}}
    end)

    assert {:ok, []} = Categories.list(config, "tok", type: :business)
  end

  test "categorise/3 posts arbitrary transactions for categorisation-as-a-service", %{
    config: config
  } do
    transactions = [%{"description" => "TESCO STORES", "amount" => -12.5}]

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/categorisation"
      assert request.options[:json] == %{"transactions" => transactions}

      {request,
       %Req.Response{
         status: 200,
         body: %{"data" => [%{"category" => "groceries"}]}
       }}
    end)

    assert {:ok, [%{"category" => "groceries"}]} =
             Categories.categorise(config, "tok", transactions)
  end

  test "get/3 fetches a single category", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/categories/cat-1"
      {request, %Req.Response{status: 200, body: %{"id" => "cat-1"}}}
    end)

    assert {:ok, %{"id" => "cat-1"}} = Categories.get(config, "tok", "cat-1")
  end

  test "create/3 posts a custom category", %{config: config} do
    attrs = %{"name" => "Side Hustle", "categoryGroup" => "income"}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/categories"
      assert request.method == :post
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "cat-new"}}}
    end)

    assert {:ok, %{"id" => "cat-new"}} = Categories.create(config, "tok", attrs)
  end

  test "list_groups/2 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/category-groups"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "income"}]}}}
    end)

    assert {:ok, [%{"id" => "income"}]} = Categories.list_groups(config, "tok")
  end
end
