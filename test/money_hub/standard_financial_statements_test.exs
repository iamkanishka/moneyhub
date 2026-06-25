defmodule MoneyHub.StandardFinancialStatementsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.StandardFinancialStatements
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

  test "create/3 requests report generation, defaulting attrs to %{}", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/standard-financial-statements"
      assert request.options[:json] == %{}
      {request, %Req.Response{status: 202, body: %{"id" => "sfs-1", "status" => "pending"}}}
    end)

    assert {:ok, %{"status" => "pending"}} = StandardFinancialStatements.create(config, "tok")
  end

  test "list/2 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "sfs-1"}]}}}
    end)

    assert {:ok, [%{"id" => "sfs-1"}]} = StandardFinancialStatements.list(config, "tok")
  end

  test "get/3 fetches a report by id", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/standard-financial-statements/sfs-1"
      {request, %Req.Response{status: 200, body: %{"id" => "sfs-1", "status" => "complete"}}}
    end)

    assert {:ok, %{"status" => "complete"}} =
             StandardFinancialStatements.get(config, "tok", "sfs-1")
  end
end
