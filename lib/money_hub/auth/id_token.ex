defmodule MoneyHub.Auth.IdToken do
  @moduledoc """
  Verifies and decodes the `id_token` returned from Moneyhub's token
  endpoint.

  The `id_token` is a JWS signed by Moneyhub's own key (published at
  `{identity_url}/oidc/certs`, see `MoneyHub.Auth.JWKS`). Its payload
  carries the resolved values of every claim requested via
  `MoneyHub.Claims` - most importantly the connected user's `sub` (when
  registering a new user) and, for payment/recurring-payment/standing-order
  flows, the resulting resource id under the matching `mh:*` claim.
  """

  alias MoneyHub.Auth.JWKS
  alias MoneyHub.Error

  @type claims :: %{optional(String.t()) => term()}

  @doc """
  Verifies the signature on a compact JWS `id_token` against Moneyhub's
  published JWKS and returns its decoded claims.

  Also performs basic structural validation: `aud` must include
  `config.client_id`, and `exp` must not be in the past.
  """
  @spec verify(String.t(), MoneyHub.Config.t()) :: {:ok, claims()} | {:error, Error.t()}
  def verify(id_token, %MoneyHub.Config{} = config) when is_binary(id_token) do
    with {:ok, kid} <- peek_kid(id_token),
         {:ok, jwks} <-
           JWKS.fetch(config.identity_url,
             finch_pool: config.finch_pool,
             http_options: config.http_options
           ),
         {:ok, jwk_map} <- JWKS.find_key(jwks, kid),
         {:ok, claims} <- verify_signature(id_token, jwk_map),
         :ok <- validate_audience(claims, config.client_id),
         :ok <- validate_expiry(claims) do
      {:ok, claims}
    end
  end

  @doc """
  Extracts a single `mh:*` (or any top-level) claim value from decoded
  `id_token` claims, returning `:error` if absent.

  Useful after `verify/2` to pull out, for example, the new user's `sub`
  or a created payment's id from `claims["mh:payment"]`.
  """
  @spec fetch(claims(), String.t()) :: {:ok, term()} | :error
  def fetch(claims, key) when is_map(claims) and is_binary(key) do
    Map.fetch(claims, key)
  end

  defp peek_kid(jwt) do
    case String.split(jwt, ".") do
      [header_b64, _payload, _sig] ->
        with {:ok, header_json} <- Base.url_decode64(header_b64, padding: false),
             {:ok, %{"kid" => kid}} <- Jason.decode(header_json) do
          {:ok, kid}
        else
          _ -> {:error, Error.jwt_error("id_token header missing kid")}
        end

      _ ->
        {:error, Error.jwt_error("id_token is not a well-formed JWS")}
    end
  end

  defp verify_signature(jwt, jwk_map) do
    jwk = JOSE.JWK.from_map(jwk_map)

    case JOSE.JWS.verify(jwk, jwt) do
      {true, payload, _jws} ->
        case Jason.decode(payload) do
          {:ok, claims} -> {:ok, claims}
          {:error, reason} -> {:error, Error.decode_error("id_token payload is not JSON", reason)}
        end

      {false, _payload, _jws} ->
        {:error, Error.jwt_error("id_token signature verification failed")}
    end
  rescue
    e -> {:error, Error.jwt_error("id_token signature verification raised", e)}
  end

  defp validate_audience(%{"aud" => aud}, client_id) do
    auds = List.wrap(aud)

    if client_id in auds do
      :ok
    else
      {:error, Error.jwt_error("id_token aud does not include this client_id")}
    end
  end

  defp validate_audience(_claims, _client_id) do
    {:error, Error.jwt_error("id_token missing aud claim")}
  end

  defp validate_expiry(%{"exp" => exp}) when is_integer(exp) do
    if exp >= System.system_time(:second) do
      :ok
    else
      {:error, Error.jwt_error("id_token has expired")}
    end
  end

  defp validate_expiry(_claims) do
    {:error, Error.jwt_error("id_token missing exp claim")}
  end
end
