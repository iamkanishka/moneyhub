defmodule MoneyHub.NotificationThresholdsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.NotificationThresholds
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
      assert to_string(request.url) =~ "/accounts/acc-1/notification-thresholds"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"id" => "nt-1"}]}}}
    end)

    assert {:ok, [%{"id" => "nt-1"}]} = NotificationThresholds.list(config, "tok", "acc-1")
  end

  test "create/4 posts a threshold", %{config: config} do
    attrs = %{"amount" => 100, "direction" => "below"}

    StubAdapter.expect(fn request ->
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "nt-1"}}}
    end)

    assert {:ok, %{"id" => "nt-1"}} = NotificationThresholds.create(config, "tok", "acc-1", attrs)
  end

  test "update/5 patches a threshold", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :patch
      assert to_string(request.url) =~ "/accounts/acc-1/notification-thresholds/nt-1"
      assert request.options[:json] == %{"amount" => 200}
      {request, %Req.Response{status: 200, body: %{"id" => "nt-1", "amount" => 200}}}
    end)

    assert {:ok, %{"amount" => 200}} =
             NotificationThresholds.update(config, "tok", "acc-1", "nt-1", %{"amount" => 200})
  end

  test "delete/4 returns :ok", %{config: config} do
    StubAdapter.expect(fn request ->
      assert request.method == :delete
      {request, %Req.Response{status: 204, body: ""}}
    end)

    assert :ok = NotificationThresholds.delete(config, "tok", "acc-1", "nt-1")
  end
end
