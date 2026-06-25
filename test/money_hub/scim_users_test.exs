defmodule MoneyHub.ScimUsersTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.ScimUsers
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
      assert to_string(request.url) =~ "/scim-users"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "su-1"}]}}}
    end)

    assert {:ok, [%{"id" => "su-1"}]} = ScimUsers.list(config, "tok")
  end

  test "create/3 posts a SCIM user", %{config: config} do
    attrs = %{"userName" => "jane@example.com"}

    StubAdapter.expect(fn request ->
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "su-1"}}}
    end)

    assert {:ok, %{"id" => "su-1"}} = ScimUsers.create(config, "tok", attrs)
  end

  test "get/3 fetches a SCIM user", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/scim-users/su-1"
      {request, %Req.Response{status: 200, body: %{"id" => "su-1"}}}
    end)

    assert {:ok, %{"id" => "su-1"}} = ScimUsers.get(config, "tok", "su-1")
  end

  test "update/4 patches a SCIM user", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :patch
      assert request.options[:json] == %{"active" => false}
      {request, %Req.Response{status: 200, body: %{"id" => "su-1", "active" => false}}}
    end)

    assert {:ok, %{"active" => false}} =
             ScimUsers.update(config, "tok", "su-1", %{"active" => false})
  end

  test "delete/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = ScimUsers.delete(config, "tok", "su-1")
  end
end
