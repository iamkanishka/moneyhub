defmodule MoneyHub.ProjectsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Projects
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
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "proj-1"}]}}}
    end)

    assert {:ok, [%{"id" => "proj-1"}]} = Projects.list(config, "tok")
  end

  test "get/3 fetches a project", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/projects/proj-1"
      {request, %Req.Response{status: 200, body: %{"id" => "proj-1"}}}
    end)

    assert {:ok, %{"id" => "proj-1"}} = Projects.get(config, "tok", "proj-1")
  end

  test "create/3 posts a project", %{config: config} do
    attrs = %{"name" => "Kitchen Renovation"}

    StubAdapter.expect(fn request ->
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "proj-1"}}}
    end)

    assert {:ok, %{"id" => "proj-1"}} = Projects.create(config, "tok", attrs)
  end

  test "update/4 patches a project", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :patch
      assert request.options[:json] == %{"name" => "New name"}
      {request, %Req.Response{status: 200, body: %{"id" => "proj-1", "name" => "New name"}}}
    end)

    assert {:ok, %{"name" => "New name"}} =
             Projects.update(config, "tok", "proj-1", %{"name" => "New name"})
  end

  test "delete/3 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = Projects.delete(config, "tok", "proj-1")
  end
end
