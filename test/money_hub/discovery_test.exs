defmodule MoneyHub.DiscoveryTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Discovery
  alias MoneyHub.Test.StubAdapter

  setup do
    config =
      Config.new!(
        client_id: "c",
        jwk: %{"kty" => "RSA"},
        jwk_kid: "k",
        identity_url: "https://identity.example.com",
        http_options: [adapter: &StubAdapter.call/1]
      )

    {:ok, config: config}
  end

  test "get/1 fetches the OIDC discovery document with no auth header", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) ==
               "https://identity.example.com/oidc/well-known/openid-configuration"

      refute Enum.any?(request.headers, fn {k, _v} ->
               String.downcase(to_string(k)) == "authorization"
             end)

      {request,
       %Req.Response{
         status: 200,
         body: %{"issuer" => "https://identity.moneyhub.co.uk", "token_endpoint" => "..."}
       }}
    end)

    assert {:ok, %{"issuer" => "https://identity.moneyhub.co.uk"}} = Discovery.get(config)
  end

  test "get/1 surfaces an api_error on failure", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 500, body: "internal error"}}
    end)

    assert {:error, error} = Discovery.get(config)
    assert error.reason == :api_error
    assert error.status == 500
  end

  test "get/1 surfaces a network_error on transport failure", %{config: config} do
    StubAdapter.expect(fn request -> {request, %Req.TransportError{reason: :timeout}} end)

    assert {:error, error} = Discovery.get(config)
    assert error.reason == :network_error
  end
end
