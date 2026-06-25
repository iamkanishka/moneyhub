defmodule MoneyHub.Auth.IdTokenTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Auth.IdToken
  alias MoneyHub.Auth.PrivateKeyJWT
  alias MoneyHub.Config
  alias MoneyHub.Test.StubAdapter

  @rsa_pem_path Path.expand("../../fixtures/rsa_key.pem", __DIR__)

  setup do
    on_exit(fn -> :persistent_term.erase({MoneyHub.Auth.JWKS, "https://identity.example.com"}) end)

    signing_jwk = PrivateKeyJWT.load_jwk!(@rsa_pem_path)
    {_, public_jwk_map} = signing_jwk |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()
    public_jwk_map = Map.put(public_jwk_map, "kid", "sig-kid-1")

    config =
      Config.new!(
        client_id: "client-abc",
        jwk: signing_jwk,
        jwk_kid: "sig-kid-1",
        identity_url: "https://identity.example.com",
        http_options: [adapter: &StubAdapter.call/1]
      )

    {:ok, config: config, signing_jwk: signing_jwk, jwks: %{"keys" => [public_jwk_map]}}
  end

  defp sign_id_token(jwk, claims) do
    {:ok, compact} = PrivateKeyJWT.sign(jwk, "sig-kid-1", claims)
    compact
  end

  defp stub_jwks(jwks) do
    StubAdapter.expect(fn request -> {request, %Req.Response{status: 200, body: jwks}} end)
  end

  describe "verify/2" do
    test "verifies a well-formed id_token signed by the published key", %{
      config: config,
      signing_jwk: jwk,
      jwks: jwks
    } do
      now = System.system_time(:second)

      id_token =
        sign_id_token(jwk, %{
          "sub" => "user-1",
          "aud" => "client-abc",
          "exp" => now + 300
        })

      stub_jwks(jwks)

      assert {:ok, claims} = IdToken.verify(id_token, config)
      assert claims["sub"] == "user-1"
    end

    test "accepts an aud that is a list containing the client_id", %{
      config: config,
      signing_jwk: jwk,
      jwks: jwks
    } do
      now = System.system_time(:second)
      id_token = sign_id_token(jwk, %{"aud" => ["other", "client-abc"], "exp" => now + 300})
      stub_jwks(jwks)

      assert {:ok, _claims} = IdToken.verify(id_token, config)
    end

    test "rejects a token whose aud does not include client_id", %{
      config: config,
      signing_jwk: jwk,
      jwks: jwks
    } do
      now = System.system_time(:second)
      id_token = sign_id_token(jwk, %{"aud" => "someone-else", "exp" => now + 300})
      stub_jwks(jwks)

      assert {:error, error} = IdToken.verify(id_token, config)
      assert error.reason == :jwt_error
      assert error.message =~ "aud"
    end

    test "rejects a token missing aud entirely", %{config: config, signing_jwk: jwk, jwks: jwks} do
      now = System.system_time(:second)
      id_token = sign_id_token(jwk, %{"exp" => now + 300})
      stub_jwks(jwks)

      assert {:error, error} = IdToken.verify(id_token, config)
      assert error.message =~ "aud"
    end

    test "rejects an expired token", %{config: config, signing_jwk: jwk, jwks: jwks} do
      now = System.system_time(:second)
      id_token = sign_id_token(jwk, %{"aud" => "client-abc", "exp" => now - 10})
      stub_jwks(jwks)

      assert {:error, error} = IdToken.verify(id_token, config)
      assert error.message =~ "expired"
    end

    test "rejects a token missing exp entirely", %{config: config, signing_jwk: jwk, jwks: jwks} do
      id_token = sign_id_token(jwk, %{"aud" => "client-abc"})
      stub_jwks(jwks)

      assert {:error, error} = IdToken.verify(id_token, config)
      assert error.message =~ "exp"
    end

    test "rejects a token signed by a key not in the JWKS", %{config: config, jwks: jwks} do
      other_jwk = JOSE.JWK.generate_key({:rsa, 2048})
      now = System.system_time(:second)

      id_token = sign_id_token(other_jwk, %{"aud" => "client-abc", "exp" => now + 300})

      stub_jwks(jwks)

      assert {:error, error} = IdToken.verify(id_token, config)
      assert error.reason == :jwt_error
    end

    test "rejects a malformed (non-JWT) string", %{config: config, jwks: jwks} do
      stub_jwks(jwks)
      assert {:error, error} = IdToken.verify("not-a-jwt", config)
      assert error.reason == :jwt_error
    end

    test "rejects when the kid is not found in the JWKS", %{
      config: config,
      signing_jwk: jwk,
      jwks: jwks
    } do
      # Sign with a kid that won't be in the served JWKS
      {:ok, compact} = PrivateKeyJWT.sign(jwk, "unknown-kid", %{"aud" => "client-abc"})
      stub_jwks(jwks)

      assert {:error, error} = IdToken.verify(compact, config)
      assert error.reason == :jwt_error
      assert error.message =~ "kid"
    end

    test "propagates a network error from the JWKS fetch", %{config: config} do
      StubAdapter.expect(fn request ->
        {request, %Req.TransportError{reason: :timeout}}
      end)

      header =
        %{"alg" => "RS256", "kid" => "some-kid"}
        |> Jason.encode!()
        |> Base.url_encode64(padding: false)

      fake_jwt = header <> ".eyJhIjoxfQ.sig"

      assert {:error, error} = IdToken.verify(fake_jwt, config)
      assert error.reason == :network_error
    end
  end

  describe "fetch/2" do
    test "returns {:ok, value} when the key is present" do
      assert {:ok, "v"} = IdToken.fetch(%{"mh:payment" => "v"}, "mh:payment")
    end

    test "returns :error when the key is absent" do
      assert :error = IdToken.fetch(%{}, "mh:payment")
    end
  end
end
