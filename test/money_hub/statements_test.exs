defmodule MoneyHub.StatementsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Statements
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
      assert to_string(request.url) =~ "/accounts/acc-1/statements"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "stmt-1"}]}}}
    end)

    assert {:ok, [%{"id" => "stmt-1"}]} = Statements.list(config, "tok", "acc-1")
  end
end
