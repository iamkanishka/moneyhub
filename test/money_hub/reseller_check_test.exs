defmodule MoneyHub.ResellerCheckTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.ResellerCheck
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

  test "check/3 posts the check payload", %{config: config} do
    attrs = %{"resellerId" => "reseller-123"}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/reseller-check"
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 200, body: %{"valid" => true}}}
    end)

    assert {:ok, %{"valid" => true}} = ResellerCheck.check(config, "tok", attrs)
  end
end
