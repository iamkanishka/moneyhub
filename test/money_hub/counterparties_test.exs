defmodule MoneyHub.CounterpartiesTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Counterparties
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

  test "list/3 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "cp-1"}]}}}
    end)

    assert {:ok, [%{"id" => "cp-1"}]} = Counterparties.list(config, "tok")
  end

  test "list/3 forwards a :limit option", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.options[:params] == %{"limit" => 5}
      {request, %Req.Response{status: 200, body: %{"data" => []}}}
    end)

    assert {:ok, []} = Counterparties.list(config, "tok", limit: 5)
  end

  test "get/3 fetches a single counterparty", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/counterparties/cp-1"
      {request, %Req.Response{status: 200, body: %{"id" => "cp-1"}}}
    end)

    assert {:ok, %{"id" => "cp-1"}} = Counterparties.get(config, "tok", "cp-1")
  end

  test "check/3 queries by name", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/counterparties-check"
      assert request.options[:params] == %{"name" => "Tesco"}
      {request, %Req.Response{status: 200, body: %{"recognised" => true}}}
    end)

    assert {:ok, %{"recognised" => true}} = Counterparties.check(config, "tok", "Tesco")
  end
end
