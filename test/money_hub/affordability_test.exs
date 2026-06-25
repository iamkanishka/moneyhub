defmodule MoneyHub.AffordabilityTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Affordability
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

  test "create/3 requests report generation, defaulting attrs to %{}", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/affordability-reports"
      assert request.options[:json] == %{}
      {request, %Req.Response{status: 202, body: %{"id" => "rep-1", "status" => "pending"}}}
    end)

    assert {:ok, %{"status" => "pending"}} = Affordability.create(config, "tok")
  end

  test "get/3 fetches a report's current status", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/affordability-reports/rep-1"
      {request, %Req.Response{status: 200, body: %{"id" => "rep-1", "status" => "complete"}}}
    end)

    assert {:ok, %{"status" => "complete"}} = Affordability.get(config, "tok", "rep-1")
  end

  describe "await/4" do
    test "polls until status leaves pending, then returns the final report", %{config: config} do
      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 200, body: %{"status" => "pending"}}}
      end)

      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 200, body: %{"status" => "pending"}}}
      end)

      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 200, body: %{"status" => "complete", "id" => "rep-1"}}}
      end)

      assert {:ok, %{"status" => "complete"}} =
               Affordability.await(config, "tok", "rep-1", interval_ms: 1)

      StubAdapter.verify!()
    end

    test "returns immediately if the report is already complete", %{config: config} do
      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 200, body: %{"status" => "complete"}}}
      end)

      assert {:ok, %{"status" => "complete"}} =
               Affordability.await(config, "tok", "rep-1", interval_ms: 1)
    end

    test "returns a validation_error after exhausting max_attempts while still pending", %{
      config: config
    } do
      for _ <- 1..3 do
        StubAdapter.expect(fn request ->
          {request, %Req.Response{status: 200, body: %{"status" => "pending"}}}
        end)
      end

      assert {:error, error} =
               Affordability.await(config, "tok", "rep-1", max_attempts: 3, interval_ms: 1)

      assert error.reason == :validation_error
      StubAdapter.verify!()
    end

    test "propagates an error from get/3 immediately without retrying", %{config: config} do
      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 404, body: %{"error" => "NOT_FOUND"}}}
      end)

      assert {:error, error} = Affordability.await(config, "tok", "rep-1", interval_ms: 1)
      assert error.reason == :api_error
      StubAdapter.verify!()
    end
  end
end
