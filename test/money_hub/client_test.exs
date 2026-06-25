defmodule MoneyHub.ClientTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Client
  alias MoneyHub.Config
  alias MoneyHub.Test.StubAdapter

  setup do
    config =
      Config.new!(
        client_id: "client-abc",
        jwk: %{"kty" => "RSA"},
        jwk_kid: "kid-1",
        api_url: "https://api.example.com/v3.0",
        http_options: [adapter: &StubAdapter.call/1]
      )

    {:ok, config: config}
  end

  describe "request/2 success paths" do
    test "issues a GET with bearer auth header and returns the response", %{config: config} do
      StubAdapter.expect(fn request ->
        assert request.method == :get
        assert to_string(request.url) == "https://api.example.com/v3.0/accounts"

        auth_header =
          Enum.find_value(request.headers, fn {k, v} ->
            if String.downcase(to_string(k)) == "authorization", do: v
          end)

        assert to_string(auth_header) == "Bearer tok-123"

        {request, %Req.Response{status: 200, body: %{"data" => []}}}
      end)

      assert {:ok, response} =
               Client.request(config, method: :get, path: "/accounts", token: "tok-123")

      assert response.status == 200
      assert response.body == %{"data" => []}
    end

    test "encodes query params", %{config: config} do
      StubAdapter.expect(fn request ->
        assert request.options[:params] == %{"accountId" => "acc-1"}
        {request, %Req.Response{status: 200, body: %{}}}
      end)

      assert {:ok, _} =
               Client.request(config,
                 method: :get,
                 path: "/transactions",
                 token: "tok-123",
                 query: %{"accountId" => "acc-1"}
               )
    end

    test "encodes a JSON body for writes", %{config: config} do
      StubAdapter.expect(fn request ->
        assert request.options[:json] == %{"name" => "Holiday Fund"}
        {request, %Req.Response{status: 201, body: %{"id" => "goal-1"}}}
      end)

      assert {:ok, response} =
               Client.request(config,
                 method: :post,
                 path: "/savings-goals",
                 token: "tok-123",
                 json: %{"name" => "Holiday Fund"}
               )

      assert response.status == 201
    end

    test "treats any 2xx as success", %{config: config} do
      StubAdapter.expect(fn request -> {request, %Req.Response{status: 204, body: ""}} end)

      assert {:ok, response} =
               Client.request(config, method: :delete, path: "/accounts/1", token: "t")

      assert response.status == 204
    end
  end

  describe "request/2 error paths" do
    test "non-2xx, non-429, non-5xx becomes an :api_error with no retry", %{config: config} do
      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 400, body: %{"error" => "INVALID_REQUEST"}}}
      end)

      assert {:error, error} = Client.request(config, method: :get, path: "/accounts", token: "t")

      assert error.reason == :api_error
      assert error.status == 400
      assert error.code == "INVALID_REQUEST"

      StubAdapter.verify!()
    end

    test "429 is retried up to max_retries, then surfaces :rate_limited", %{config: config} do
      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 429, headers: %{"retry-after" => ["0"]}, body: %{}}}
      end)

      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 429, headers: %{"retry-after" => ["0"]}, body: %{}}}
      end)

      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 429, headers: %{"retry-after" => ["0"]}, body: %{}}}
      end)

      assert {:error, error} =
               Client.request(config,
                 method: :get,
                 path: "/accounts",
                 token: "t",
                 max_retries: 2,
                 max_retry_after_ms: 10
               )

      assert error.reason == :rate_limited
      assert error.status == 429
      StubAdapter.verify!()
    end

    test "429 followed by a 200 succeeds after one retry", %{config: config} do
      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 429, headers: %{"retry-after" => ["0"]}, body: %{}}}
      end)

      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 200, body: %{"data" => []}}}
      end)

      assert {:ok, response} =
               Client.request(config,
                 method: :get,
                 path: "/accounts",
                 token: "t",
                 max_retry_after_ms: 10
               )

      assert response.status == 200
      StubAdapter.verify!()
    end

    test "5xx is retried, then surfaces :api_error if still failing", %{config: config} do
      StubAdapter.expect(fn request -> {request, %Req.Response{status: 503, body: ""}} end)
      StubAdapter.expect(fn request -> {request, %Req.Response{status: 503, body: ""}} end)
      StubAdapter.expect(fn request -> {request, %Req.Response{status: 503, body: ""}} end)

      assert {:error, error} =
               Client.request(config, method: :get, path: "/accounts", token: "t", max_retries: 2)

      assert error.reason == :api_error
      assert error.status == 503
      StubAdapter.verify!()
    end

    test "network/transport errors are retried, then surface :network_error", %{config: config} do
      StubAdapter.expect(fn request -> {request, %Req.TransportError{reason: :timeout}} end)
      StubAdapter.expect(fn request -> {request, %Req.TransportError{reason: :timeout}} end)
      StubAdapter.expect(fn request -> {request, %Req.TransportError{reason: :timeout}} end)

      assert {:error, error} =
               Client.request(config, method: :get, path: "/accounts", token: "t", max_retries: 2)

      assert error.reason == :network_error
      StubAdapter.verify!()
    end

    test "network error followed by success recovers", %{config: config} do
      StubAdapter.expect(fn request -> {request, %Req.TransportError{reason: :timeout}} end)
      StubAdapter.expect(fn request -> {request, %Req.Response{status: 200, body: %{}}} end)

      assert {:ok, response} = Client.request(config, method: :get, path: "/accounts", token: "t")

      assert response.status == 200
      StubAdapter.verify!()
    end
  end

  describe "unwrap_list/1" do
    test "extracts \"data\" from a map envelope" do
      assert Client.unwrap_list(%{"data" => [1, 2, 3]}) == [1, 2, 3]
    end

    test "returns a bare list unchanged (regression: must not raise ArgumentError)" do
      assert Client.unwrap_list([1, 2, 3]) == [1, 2, 3]
    end

    test "returns a map with no \"data\" key unchanged" do
      assert Client.unwrap_list(%{"id" => "x"}) == %{"id" => "x"}
    end

    test "returns other shapes (string, nil) unchanged" do
      assert Client.unwrap_list("") == ""
      assert Client.unwrap_list(nil) == nil
    end
  end
end
