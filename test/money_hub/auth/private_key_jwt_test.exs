defmodule MoneyHub.Auth.PrivateKeyJWTTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Auth.PrivateKeyJWT
  alias MoneyHub.Config

  @rsa_pem_path Path.expand("../../fixtures/rsa_key.pem", __DIR__)
  @ec_pem_path Path.expand("../../fixtures/ec_key.pem", __DIR__)

  describe "load_jwk!/1 and jwk_from_pem!/1" do
    test "loads an RSA private key from disk" do
      assert %JOSE.JWK{} = jwk = PrivateKeyJWT.load_jwk!(@rsa_pem_path)
      assert {_, %{"kty" => "RSA"}} = JOSE.JWK.to_map(jwk)
    end

    test "loads an EC private key from disk" do
      assert %JOSE.JWK{} = jwk = PrivateKeyJWT.load_jwk!(@ec_pem_path)
      assert {_, %{"kty" => "EC"}} = JOSE.JWK.to_map(jwk)
    end

    test "jwk_from_pem!/1 raises MoneyHub.Error on garbage input" do
      assert_raise MoneyHub.Error, fn ->
        PrivateKeyJWT.jwk_from_pem!("not a pem")
      end
    end

    test "load_jwk!/1 raises File.Error for a missing path" do
      assert_raise File.Error, fn ->
        PrivateKeyJWT.load_jwk!("/nonexistent/path.pem")
      end
    end
  end

  describe "sign/3" do
    test "signs with RS256 for an RSA key and embeds the kid" do
      jwk = PrivateKeyJWT.load_jwk!(@rsa_pem_path)
      assert {:ok, compact} = PrivateKeyJWT.sign(jwk, "rsa-kid-1", %{"hello" => "world"})

      [header_b64, payload_b64, _sig] = String.split(compact, ".")
      header = header_b64 |> Base.url_decode64!(padding: false) |> Jason.decode!()
      payload = payload_b64 |> Base.url_decode64!(padding: false) |> Jason.decode!()

      assert header == %{"alg" => "RS256", "kid" => "rsa-kid-1", "typ" => "JWT"}
      assert payload == %{"hello" => "world"}

      assert {true, _payload, _jws} = JOSE.JWS.verify(jwk, compact)
    end

    test "signs with ES256 for an EC key" do
      jwk = PrivateKeyJWT.load_jwk!(@ec_pem_path)
      assert {:ok, compact} = PrivateKeyJWT.sign(jwk, "ec-kid-1", %{"hello" => "world"})

      [header_b64, _payload_b64, _sig] = String.split(compact, ".")
      header = header_b64 |> Base.url_decode64!(padding: false) |> Jason.decode!()
      assert header["alg"] == "ES256"

      assert {true, _payload, _jws} = JOSE.JWS.verify(jwk, compact)
    end

    test "accepts a plain JWK map as well as a %JOSE.JWK{} struct" do
      jwk_struct = PrivateKeyJWT.load_jwk!(@rsa_pem_path)
      {_, jwk_map} = JOSE.JWK.to_map(jwk_struct)

      assert {:ok, compact} = PrivateKeyJWT.sign(jwk_map, "kid", %{"a" => 1})
      assert {true, _payload, _jws} = JOSE.JWS.verify(jwk_struct, compact)
    end
  end

  describe "sign_client_assertion/1" do
    setup do
      jwk = PrivateKeyJWT.load_jwk!(@rsa_pem_path)

      config =
        Config.new!(
          client_id: "client-abc",
          jwk: jwk,
          jwk_kid: "kid-abc",
          identity_url: "https://identity.example.com"
        )

      {:ok, config: config, jwk: jwk}
    end

    test "builds a well-formed RFC 7523 assertion", %{config: config, jwk: jwk} do
      assert {:ok, compact} = PrivateKeyJWT.sign_client_assertion(config)

      [_header_b64, payload_b64, _sig] = String.split(compact, ".")
      payload = payload_b64 |> Base.url_decode64!(padding: false) |> Jason.decode!()

      assert payload["iss"] == "client-abc"
      assert payload["sub"] == "client-abc"
      assert payload["aud"] == "https://identity.example.com/oidc/token"
      assert is_binary(payload["jti"])
      assert is_integer(payload["iat"])
      assert payload["exp"] == payload["iat"] + 60

      assert {true, _payload, _jws} = JOSE.JWS.verify(jwk, compact)
    end

    test "generates a fresh jti on every call", %{config: config} do
      {:ok, c1} = PrivateKeyJWT.sign_client_assertion(config)
      {:ok, c2} = PrivateKeyJWT.sign_client_assertion(config)

      jti = fn compact ->
        [_h, p, _s] = String.split(compact, ".")
        p |> Base.url_decode64!(padding: false) |> Jason.decode!() |> Map.fetch!("jti")
      end

      assert jti.(c1) != jti.(c2)
    end
  end
end
