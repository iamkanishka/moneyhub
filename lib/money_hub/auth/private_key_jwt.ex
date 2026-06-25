defmodule MoneyHub.Auth.PrivateKeyJWT do
  @moduledoc """
  Builds and signs `private_key_jwt` client assertions.

  Moneyhub's `/oidc/token` endpoint authenticates confidential clients via
  [RFC 7523](https://datatracker.ietf.org/doc/html/rfc7523) `private_key_jwt`:
  instead of sending a client secret, the client signs a short-lived JWT
  with its own private key and presents that JWT as proof of identity.

  This module builds that assertion (`client_assertion`) and is also used
  to sign request objects (the `request` parameter sent to `/oidc/auth` /
  `/oidc/request` and to payment/payee creation endpoints).

  ## Loading a key

  Moneyhub issues an RSA (or EC) private key when a client/software
  certificate is registered. Load it as a `JOSE.JWK`:

      jwk = MoneyHub.Auth.PrivateKeyJWT.load_jwk!("priv/keys/client.pem")

  or build one directly from PEM contents already in memory (e.g. from an
  environment variable or secrets manager):

      jwk = MoneyHub.Auth.PrivateKeyJWT.jwk_from_pem!(pem_contents)

  """

  alias MoneyHub.Error

  @type claims :: %{optional(String.t()) => term()}

  @doc """
  Loads a PEM-encoded private key from disk into a `JOSE.JWK`.

  Raises `MoneyHub.Error` if the file cannot be read or parsed.
  """
  @spec load_jwk!(Path.t()) :: JOSE.JWK.t()
  def load_jwk!(path) do
    path
    |> File.read!()
    |> jwk_from_pem!()
  end

  @doc """
  Builds a `JOSE.JWK` from PEM-encoded private key contents.

  Raises `MoneyHub.Error` if the PEM cannot be parsed.
  """
  @spec jwk_from_pem!(String.t()) :: JOSE.JWK.t()
  def jwk_from_pem!(pem) when is_binary(pem) do
    case JOSE.JWK.from_pem(pem) do
      %JOSE.JWK{} = jwk ->
        jwk

      other ->
        raise Error.jwt_error("could not parse private key PEM", other)
    end
  end

  @doc """
  Signs a `private_key_jwt` client assertion for the token endpoint.

  Per RFC 7523 / OIDC, the assertion asserts the client's own identity to
  itself as audience:

    * `iss` / `sub` - the `client_id`
    * `aud` - the token endpoint URL (`identity_url <> "/oidc/token"`)
    * `jti` - a fresh unique identifier (replay protection)
    * `iat` / `exp` - issued-now, short expiry (60 seconds)

  Returns the signed compact JWS as a string.
  """
  @spec sign_client_assertion(MoneyHub.Config.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def sign_client_assertion(%MoneyHub.Config{} = config) do
    aud = config.identity_url <> "/oidc/token"
    now = System.system_time(:second)

    claims = %{
      "iss" => config.client_id,
      "sub" => config.client_id,
      "aud" => aud,
      "jti" => generate_jti(),
      "iat" => now,
      "exp" => now + 60
    }

    sign(config.jwk, config.jwk_kid, claims)
  end

  @doc """
  Signs an arbitrary claims map as a compact JWS using the given JWK.

  The signing algorithm is derived from the key type: `RS256` for RSA keys,
  `ES256` for EC P-256 keys. The `kid` is always embedded in the JWS header
  so Moneyhub can select the matching public key from your registered JWKS.
  """
  @spec sign(JOSE.JWK.t() | map(), String.t(), claims()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def sign(jwk, kid, claims) when is_binary(kid) and is_map(claims) do
    jwk = to_jose_jwk(jwk)
    alg = signing_alg(jwk)

    jws = %{"alg" => alg, "kid" => kid, "typ" => "JWT"}

    {%{}, compact} =
      jwk
      |> JOSE.JWS.sign(Jason.encode!(claims), jws)
      |> JOSE.JWS.compact()

    {:ok, compact}
  rescue
    e -> {:error, Error.jwt_error("failed to sign JWT", e)}
  end

  defp to_jose_jwk(%JOSE.JWK{} = jwk), do: jwk
  defp to_jose_jwk(map) when is_map(map), do: JOSE.JWK.from_map(map)

  defp signing_alg(jwk) do
    case JOSE.JWK.to_map(jwk) do
      {_, %{"kty" => "EC"}} -> "ES256"
      {_, %{"kty" => "RSA"}} -> "RS256"
      {_, other} -> raise Error.jwt_error("unsupported key type for signing", other)
    end
  end

  defp generate_jti do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
