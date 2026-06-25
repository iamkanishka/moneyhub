defmodule MoneyHub.Webhooks do
  @moduledoc """
  Verifies and parses incoming Moneyhub webhook deliveries.

  Moneyhub can deliver webhooks as plain JSON or as a signed JWT (a
  "Security Event Token" style payload) - which one you receive depends on
  how the webhook endpoint was configured in the admin portal. `parse/2`
  handles both transparently: given the raw request body (as a string) and
  your `MoneyHub.Config`, it detects which shape was sent, verifies the
  signature if present, and returns a `MoneyHub.Webhooks.Event`.

  Moneyhub's webhook delivery has a **5 second response timeout** and
  performs **at most one retry** - your endpoint must acknowledge quickly
  (return `200` immediately, do slow processing afterwards) or events will
  be lost.

  ## Example (Plug-based webhook endpoint)

      def handle_webhook(conn, _params) do
        {:ok, raw_body, conn} = Plug.Conn.read_body(conn)

        case MoneyHub.Webhooks.parse(raw_body, config) do
          {:ok, %MoneyHub.Webhooks.Event{id: "newTransactions"} = event} ->
            MyApp.Jobs.enqueue(:sync_transactions, event.payload)
            Plug.Conn.send_resp(conn, 200, "")

          {:ok, %MoneyHub.Webhooks.Event{} = event} ->
            MyApp.Jobs.enqueue(:handle_webhook, event)
            Plug.Conn.send_resp(conn, 200, "")

          {:error, _reason} ->
            Plug.Conn.send_resp(conn, 400, "")
        end
      end

  """

  alias MoneyHub.Auth.JWKS
  alias MoneyHub.Error
  alias MoneyHub.Webhooks.Event

  @doc """
  Parses and verifies a raw webhook request body, returning a
  `MoneyHub.Webhooks.Event` struct.

  Detects whether `raw_body` is a plain JSON object or a compact JWS
  (three base64url segments separated by `.`) and verifies accordingly.
  Plain JSON deliveries have no signature to check at the payload level
  (verify transport security / a shared secret header instead, if your
  webhook configuration uses one); JWT deliveries are verified against
  Moneyhub's published JWKS exactly like an `id_token`.
  """
  @spec parse(String.t(), MoneyHub.Config.t()) :: {:ok, Event.t()} | {:error, Error.t()}
  def parse(raw_body, %MoneyHub.Config{} = config) when is_binary(raw_body) do
    if jwt_shaped?(raw_body) do
      parse_jwt(raw_body, config)
    else
      parse_json(raw_body)
    end
  end

  defp jwt_shaped?(body) do
    case String.split(String.trim(body), ".") do
      [_, _, _] -> true
      _ -> false
    end
  end

  defp parse_json(raw_body) do
    case Jason.decode(raw_body) do
      {:ok, %{"id" => _} = decoded} -> {:ok, Event.from_map(decoded)}
      {:ok, _other} -> {:error, Error.decode_error("webhook JSON missing required \"id\" field")}
      {:error, reason} -> {:error, Error.decode_error("webhook body is not valid JSON", reason)}
    end
  end

  defp parse_jwt(jwt, config) do
    with {:ok, kid} <- peek_kid(jwt),
         {:ok, jwks} <-
           JWKS.fetch(config.identity_url,
             finch_pool: config.finch_pool,
             http_options: config.http_options
           ),
         {:ok, jwk_map} <- JWKS.find_key(jwks, kid),
         {:ok, claims} <- verify_signature(jwt, jwk_map) do
      {:ok, Event.from_map(claims)}
    end
  end

  defp peek_kid(jwt) do
    case String.split(jwt, ".") do
      [header_b64, _payload, _sig] ->
        with {:ok, header_json} <- Base.url_decode64(header_b64, padding: false),
             {:ok, %{"kid" => kid}} <- Jason.decode(header_json) do
          {:ok, kid}
        else
          _ -> {:error, Error.jwt_error("webhook JWT header missing kid")}
        end

      _ ->
        {:error, Error.jwt_error("webhook payload is not a well-formed JWS")}
    end
  end

  defp verify_signature(jwt, jwk_map) do
    jwk = JOSE.JWK.from_map(jwk_map)

    case JOSE.JWS.verify(jwk, jwt) do
      {true, payload, _jws} ->
        case Jason.decode(payload) do
          {:ok, claims} ->
            {:ok, claims}

          {:error, reason} ->
            {:error, Error.decode_error("webhook JWT payload is not JSON", reason)}
        end

      {false, _payload, _jws} ->
        {:error, Error.jwt_error("webhook JWT signature verification failed")}
    end
  rescue
    e -> {:error, Error.jwt_error("webhook JWT signature verification raised", e)}
  end
end
