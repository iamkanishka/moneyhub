defmodule MoneyHub.WebhooksTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Auth.PrivateKeyJWT
  alias MoneyHub.Config
  alias MoneyHub.Test.StubAdapter
  alias MoneyHub.Webhooks
  alias MoneyHub.Webhooks.Event

  @rsa_pem_path Path.expand("../fixtures/rsa_key.pem", __DIR__)

  setup do
    on_exit(fn ->
      :persistent_term.erase({MoneyHub.Auth.JWKS, "https://identity.example.com"})
    end)

    config =
      Config.new!(
        client_id: "client-abc",
        jwk: %{"kty" => "RSA"},
        jwk_kid: "kid-1",
        identity_url: "https://identity.example.com",
        http_options: [adapter: &StubAdapter.call/1]
      )

    {:ok, config: config}
  end

  describe "parse/2 with plain JSON delivery" do
    test "parses a newTransactions event", %{config: config} do
      body =
        Jason.encode!(%{
          "id" => "newTransactions",
          "userId" => "user-1",
          "connectionId" => "con-1",
          "payload" => %{"transactionIds" => ["t1", "t2"]}
        })

      assert {:ok, %Event{} = event} = Webhooks.parse(body, config)
      assert event.id == "newTransactions"
      assert event.user_id == "user-1"
      assert event.connection_id == "con-1"
      assert event.payload == %{"transactionIds" => ["t1", "t2"]}
    end

    test "falls back to the raw map (minus id/userId/connectionId) when there is no payload key",
         %{config: config} do
      body = Jason.encode!(%{"id" => "deletedAccount", "accountId" => "acc-1"})

      assert {:ok, %Event{} = event} = Webhooks.parse(body, config)
      assert event.id == "deletedAccount"
      assert event.payload == %{"accountId" => "acc-1"}
    end

    test "errors when JSON is malformed", %{config: config} do
      assert {:error, error} = Webhooks.parse("{not json", config)
      assert error.reason == :decode_error
    end

    test "errors when JSON is valid but missing the required id field", %{config: config} do
      assert {:error, error} = Webhooks.parse(Jason.encode!(%{"foo" => "bar"}), config)
      assert error.reason == :decode_error
      assert error.message =~ "id"
    end
  end

  describe "parse/2 with signed JWT delivery" do
    setup %{config: config} do
      signing_jwk = PrivateKeyJWT.load_jwk!(@rsa_pem_path)
      {_, public_jwk_map} = signing_jwk |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()
      public_jwk_map = Map.put(public_jwk_map, "kid", "webhook-kid-1")

      {:ok, config: config, signing_jwk: signing_jwk, jwks: %{"keys" => [public_jwk_map]}}
    end

    defp stub_jwks(jwks) do
      StubAdapter.expect(fn request -> {request, %Req.Response{status: 200, body: jwks}} end)
    end

    test "verifies and parses a JWT-delivered event", %{
      config: config,
      signing_jwk: jwk,
      jwks: jwks
    } do
      claims = %{
        "id" => "paymentCompleted",
        "userId" => "user-1",
        "payload" => %{"paymentId" => "pay-1"}
      }

      {:ok, jwt} = PrivateKeyJWT.sign(jwk, "webhook-kid-1", claims)
      stub_jwks(jwks)

      assert {:ok, %Event{} = event} = Webhooks.parse(jwt, config)
      assert event.id == "paymentCompleted"
      assert event.user_id == "user-1"
      assert event.payload == %{"paymentId" => "pay-1"}
    end

    test "rejects a JWT signed by an unknown key", %{config: config, jwks: jwks} do
      other_jwk = JOSE.JWK.generate_key({:rsa, 2048})
      {:ok, jwt} = PrivateKeyJWT.sign(other_jwk, "webhook-kid-1", %{"id" => "x"})
      stub_jwks(jwks)

      assert {:error, error} = Webhooks.parse(jwt, config)
      assert error.reason == :jwt_error
    end

    test "rejects a JWT whose kid is absent from the JWKS", %{
      config: config,
      signing_jwk: jwk,
      jwks: jwks
    } do
      {:ok, jwt} = PrivateKeyJWT.sign(jwk, "totally-different-kid", %{"id" => "x"})
      stub_jwks(jwks)

      assert {:error, error} = Webhooks.parse(jwt, config)
      assert error.reason == :jwt_error
      assert error.message =~ "kid"
    end

    test "rejects a tampered JWT (bad signature)", %{
      config: config,
      signing_jwk: jwk,
      jwks: jwks
    } do
      {:ok, jwt} = PrivateKeyJWT.sign(jwk, "webhook-kid-1", %{"id" => "x"})
      [header, payload, _sig] = String.split(jwt, ".")
      tampered = header <> "." <> payload <> ".tamperedsignature"
      stub_jwks(jwks)

      assert {:error, error} = Webhooks.parse(tampered, config)
      assert error.reason == :jwt_error
    end
  end

  test "Event.from_map/1 defaults user_id/connection_id to nil when absent" do
    event = Event.from_map(%{"id" => "syncCompleted"})
    assert event.id == "syncCompleted"
    assert event.user_id == nil
    assert event.connection_id == nil
    assert event.payload == %{}
  end
end
