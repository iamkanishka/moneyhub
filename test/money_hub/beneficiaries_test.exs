defmodule MoneyHub.BeneficiariesTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Beneficiaries
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

  test "list/2 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/beneficiaries"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "ben-1"}]}}}
    end)

    assert {:ok, [%{"id" => "ben-1"}]} = Beneficiaries.list(config, "tok")
  end

  test "get/3 fetches a single beneficiary", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/beneficiaries/ben-1"
      {request, %Req.Response{status: 200, body: %{"id" => "ben-1"}}}
    end)

    assert {:ok, %{"id" => "ben-1"}} = Beneficiaries.get(config, "tok", "ben-1")
  end
end
