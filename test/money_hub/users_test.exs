defmodule MoneyHub.UsersTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Test.StubAdapter
  alias MoneyHub.Users

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

  test "get/3 fetches a user record", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/users/user-1"
      {request, %Req.Response{status: 200, body: %{"id" => "user-1"}}}
    end)

    assert {:ok, %{"id" => "user-1"}} = Users.get(config, "tok", "user-1")
  end

  test "delete/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = Users.delete(config, "tok", "user-1")
  end

  test "propagates errors", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 404, body: %{"error" => "NOT_FOUND"}}}
    end)

    assert {:error, error} = Users.get(config, "tok", "missing")
    assert error.status == 404
  end

  test "list_connections/3 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/users/user-1/connections"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "con-1"}]}}}
    end)

    assert {:ok, [%{"id" => "con-1"}]} = Users.list_connections(config, "tok", "user-1")
  end

  test "get_connection/4 fetches a single connection", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/users/user-1/connections/con-1"
      {request, %Req.Response{status: 200, body: %{"id" => "con-1"}}}
    end)

    assert {:ok, %{"id" => "con-1"}} = Users.get_connection(config, "tok", "user-1", "con-1")
  end

  test "delete_connection/4 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      assert to_string(request.url) =~ "/users/user-1/connections/con-1"
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = Users.delete_connection(config, "tok", "user-1", "con-1")
  end

  test "list_syncs/3 unwraps the data envelope", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/users/user-1/syncs"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"connectionId" => "con-1"}]}}}
    end)

    assert {:ok, [%{"connectionId" => "con-1"}]} = Users.list_syncs(config, "tok", "user-1")
  end
end
