defmodule MoneyHub.HoldingsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config
  alias MoneyHub.Holdings
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

  test "list/3 fetches raw holdings for an account", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/accounts/acc-1/holdings"
      {request, %Req.Response{status: 200, body: %{"data" => [%{"isin" => "GB00B03MLX29"}]}}}
    end)

    assert {:ok, [%{"isin" => "GB00B03MLX29"}]} = Holdings.list(config, "tok", "acc-1")
  end

  test "list_with_matches/3 fetches ISIN-enriched holdings", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/accounts/acc-1/holdings-with-matches"

      {request,
       %Req.Response{
         status: 200,
         body: %{"data" => [%{"isin" => "GB00B03MLX29", "matchedSecurity" => %{}}]}
       }}
    end)

    assert {:ok, [%{"matchedSecurity" => %{}}]} =
             Holdings.list_with_matches(config, "tok", "acc-1")
  end

  test "get/4 fetches a single holding", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/accounts/acc-1/holdings/h-1"
      {request, %Req.Response{status: 200, body: %{"id" => "h-1"}}}
    end)

    assert {:ok, %{"id" => "h-1"}} = Holdings.get(config, "tok", "acc-1", "h-1")
  end
end
