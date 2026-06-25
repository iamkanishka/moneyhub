defmodule MoneyHub.RentalRecordsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.RentalRecords
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

  test "create/3 posts the tenancy payload", %{config: config} do
    attrs = %{"monthlyRent" => 950, "landlord" => "Acme Lettings"}

    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/rental-records"
      assert request.options[:json] == attrs
      {request, %Req.Response{status: 201, body: %{"id" => "rr-1", "status" => "pending"}}}
    end)

    assert {:ok, %{"id" => "rr-1"}} = RentalRecords.create(config, "tok", attrs)
  end

  test "get/3 fetches a rental record's status", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/rental-records/rr-1"
      {request, %Req.Response{status: 200, body: %{"id" => "rr-1", "status" => "submitted"}}}
    end)

    assert {:ok, %{"status" => "submitted"}} = RentalRecords.get(config, "tok", "rr-1")
  end
end
