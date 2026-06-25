defmodule MoneyHub.SpendingGoalsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.SpendingGoals
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

  test "create/3 posts a budgeting goal", %{config: config} do
    attrs = %{"category" => "groceries", "targetAmount" => 500, "period" => "monthly"}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/spending-goals"
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "sg-1"}}}
    end)

    assert {:ok, %{"id" => "sg-1"}} = SpendingGoals.create(config, "tok", attrs)
  end

  test "list/2 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "sg-1"}]}}}
    end)

    assert {:ok, [%{"id" => "sg-1"}]} = SpendingGoals.list(config, "tok")
  end

  test "get/3 fetches a goal", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/spending-goals/sg-1"
      {request, %Req.Response{status: 200, body: %{"id" => "sg-1"}}}
    end)

    assert {:ok, %{"id" => "sg-1"}} = SpendingGoals.get(config, "tok", "sg-1")
  end

  test "delete/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = SpendingGoals.delete(config, "tok", "sg-1")
  end
end
