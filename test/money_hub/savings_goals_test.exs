defmodule MoneyHub.SavingsGoalsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.SavingsGoals
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

  test "create/3 posts a goal spanning multiple accounts", %{config: config} do
    attrs = %{"name" => "Holiday", "targetAmount" => 2000, "accountIds" => ["a1", "a2"]}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/savings-goals"
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "goal-1"}}}
    end)

    assert {:ok, %{"id" => "goal-1"}} = SavingsGoals.create(config, "tok", attrs)
  end

  test "list/2 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "goal-1"}]}}}
    end)

    assert {:ok, [%{"id" => "goal-1"}]} = SavingsGoals.list(config, "tok")
  end

  test "get/3 fetches a goal with progress", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/savings-goals/goal-1"

      {request,
       %Req.Response{
         status: 200,
         body: %{"id" => "goal-1", "progressAmount" => 500, "progressPercentage" => 25}
       }}
    end)

    assert {:ok, %{"progressPercentage" => 25}} = SavingsGoals.get(config, "tok", "goal-1")
  end

  test "update/4 patches a goal", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :patch
      assert request.options[:json] == %{"targetAmount" => 3000}
      {request, %Req.Response{status: 200, body: %{"id" => "goal-1", "targetAmount" => 3000}}}
    end)

    assert {:ok, %{"targetAmount" => 3000}} =
             SavingsGoals.update(config, "tok", "goal-1", %{"targetAmount" => 3000})
  end

  test "delete/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = SavingsGoals.delete(config, "tok", "goal-1")
  end
end
