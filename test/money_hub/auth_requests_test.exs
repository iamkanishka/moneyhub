defmodule MoneyHub.AuthRequestsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.AuthRequests
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

  test "create/3 posts scope/claims and returns a hosted url", %{config: config} do
    attrs = %{"scope" => "openid accounts:read"}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/auth-requests"
      assert request.options[:json] == attrs

      {request,
       %Req.Response{
         status: 201,
         body: %{"id" => "ar-1", "url" => "https://identity.moneyhub.co.uk/oidc/auth?..."}
       }}
    end)

    assert {:ok, %{"url" => url}} = AuthRequests.create(config, "tok", attrs)
    assert url =~ "oidc/auth"
  end

  test "list/2 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/auth-requests"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "ar-1"}]}}}
    end)

    assert {:ok, [%{"id" => "ar-1"}]} = AuthRequests.list(config, "tok")
  end

  test "get/3 fetches an auth request's status", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/auth-requests/ar-1"
      {request, %Req.Response{status: 200, body: %{"id" => "ar-1", "status" => "completed"}}}
    end)

    assert {:ok, %{"status" => "completed"}} = AuthRequests.get(config, "tok", "ar-1")
  end

  test "update/4 patches an auth request", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :patch
      assert to_string(request.url) =~ "/auth-requests/ar-1"
      assert request.options[:json] == %{"status" => "cancelled"}
      {request, %Req.Response{status: 200, body: %{"id" => "ar-1", "status" => "cancelled"}}}
    end)

    assert {:ok, %{"status" => "cancelled"}} =
             AuthRequests.update(config, "tok", "ar-1", %{"status" => "cancelled"})
  end
end
