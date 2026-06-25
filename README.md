# MoneyHub

[![Hex.pm](https://img.shields.io/badge/hex-money_hub-blueviolet)](https://hex.pm/packages/money_hub)

A production-grade Elixir client for the [Moneyhub Open Finance API](https://docs.moneyhubenterprise.com/) -
Open Banking account aggregation (AIS), payment initiation (PIS), data
categorisation/enrichment, affordability, and webhooks.

## Features

- **OpenID Connect authentication** - Pushed Authorisation Requests (PAR),
  private_key_jwt client assertions, request objects, authorisation code
  exchange, client_credentials tokens for ongoing per-user access, refresh
  tokens, and OIDC discovery.
- **Data Aggregation (AIS)** - accounts (incl. manual balances, standing
  orders, sync status), balances, transactions (incl. manual transactions,
  splits, file attachments), regular transaction (subscription/rent/salary)
  detection, connections lifecycle (incl. immediate sync and connection-type
  filtered catalogs), categories and category groups,
  categorisation-as-a-service, counterparties (per-user and global),
  beneficiaries, investment holdings with ISIN matching, spending analysis,
  savings/spending goals, rental records, affordability reports, Standard
  Financial Statements, notification thresholds, account statements, tax
  (SA105) data, projects, consent history, bank icons, reseller checks,
  and both lightweight (Users) and SCIM-based (ScimUsers) user records.
- **Payments (PIS)** - payees, single immediate payments, Variable
  Recurring Payments (VRP) with sweep triggering and funds confirmation,
  standing orders, bulk pay files, shareable pay links, and refunds.
- **Webhooks** - verifies both plain-JSON and signed-JWT webhook deliveries
  against Moneyhub's published JWKS.
- Built on [Req](https://hex.pm/packages/req) with automatic retry/backoff
  for 429 and 5xx responses, structured MoneyHub.Error results instead
  of bare tuples, full @specs, and telemetry instrumentation.

## Installation

Add money_hub to your mix.exs dependencies:

```elixir
def deps do
  [
    {:money_hub, "~> 1.0.0"}
  ]
end
```

MoneyHub.Application starts a supervised Finch connection pool
(MoneyHub.Finch) automatically - no extra setup required. To tune pool
sizing:

```elixir
# config/config.exs
config :money_hub, :finch_pools, %{default: [size: 25, count: 1]}
```

> **Note:** money_hub intentionally does not depend on :castore. It's
> only used by the underlying HTTP stack (Req/Finch/Mint) as an
> _optional_ CA-certificate fallback, and explicitly adding it pulls in a
> mix certdata build task that fails to compile on some Erlang/OTP
> installations - this is a common, longstanding issue on Windows and on
> some minimal Linux Erlang packages, where the public_key application's
> include/ headers aren't present. Without it, the stack falls back to
> :public_key.cacerts_get/0 (built into OTP 25+), which works
> everywhere and is all that's needed here.

## Configuration

Build a MoneyHub.Config once and pass it to every call. In production,
Moneyhub requires private_key_jwt client authentication - load the
private key Moneyhub issued you when registering your client/software
certificate:

```elixir
config =
  MoneyHub.Config.new!(
    environment: :production,
    client_id: System.fetch_env!("MONEYHUB_CLIENT_ID"),
    jwk: MoneyHub.Auth.PrivateKeyJWT.load_jwk!(System.fetch_env!("MONEYHUB_PRIVATE_KEY_PATH")),
    jwk_kid: System.fetch_env!("MONEYHUB_KEY_ID"),
    redirect_uri: "https://myapp.example.com/moneyhub/callback"
  )

```

# For early sandbox development, client_secret_basic is also supported:

```elixir
config =
  MoneyHub.Config.new!(
    environment: :sandbox,
    client_id: "...",
    client_secret: "...",
    token_endpoint_auth_method: :client_secret_basic,
    redirect_uri: "https://myapp.example.com/moneyhub/callback"
  )
```

## Quick start: connect a bank account, then read transactions

```elixir
alias MoneyHub.{Auth, Claims, Scopes, Accounts, Transactions}
alias MoneyHub.Auth.IdToken
```

# 1. Build an authorisation URL for a new user (Moneyhub assigns the sub)

claims = Claims.new() |> Claims.put_sub()

```elixir
{:ok, %{url: url}} =
  Auth.pushed_authorisation_request(config, scope: Scopes.ais_offline(), claims: claims)
```

# 2. Redirect the user's browser to url. They authenticate at their bank

# and are redirected back to your redirect_uri with ?code=...&state=....

# 3. Exchange the code for tokens and verify the id_token

```elixir
{:ok, tokens} = Auth.exchange_code(config, code)
{:ok, id_claims} = IdToken.verify(tokens.id_token, config)
user_id = id_claims["sub"]
```

# 4. From now on, fetch fresh data tokens for this user as needed

```elixir
{:ok, data_token} = Auth.token_for_user(config, user_id)
{:ok, accounts} = Accounts.list(config, data_token.access_token)
{:ok, transactions} =
  Transactions.list(config, data_token.access_token, account_id: hd(accounts)["id"])

```

## Quick start: a single immediate payment

```elixir
alias MoneyHub.{Auth, Claims, Scopes}
alias MoneyHub.Auth.IdToken

payment = %{
  "amount" => %{"amount" => 10.50, "currency" => "GBP"},
  "creditorAccount" => %{
    "identification" => %{"sortCode" => "010203", "accountNumber" => "12345678"}
  },
  "reference" => "Invoice 123"
}

claims = Claims.new() |> Claims.put_sub() |> Claims.put_payment(payment)

{:ok, %{url: url}} =
  Auth.pushed_authorisation_request(config, scope: Scopes.payments(), claims: claims)

# redirect the user to url to authorise the payment at their bank, then:

{:ok, tokens} = Auth.exchange_code(config, code)
{:ok, id_claims} = IdToken.verify(tokens.id_token, config)
{:ok, payment_id} = IdToken.fetch(id_claims, "mh:payment")
```

## Webhooks

```elixir
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
```

Moneyhub's webhook delivery has a 5 second response timeout and at most one
retry - acknowledge with 200 immediately and do slow processing
afterwards.

## Error handling

Every function that can fail returns {:error, %MoneyHub.Error{}} with a
structured reason (:config_error, :network_error, :api_error,
:rate_limited, :decode_error, :jwt_error, :validation_error) instead
of ad-hoc tuples:

```elixir
case MoneyHub.Accounts.list(config, token) do
  {:ok, accounts} ->
    accounts

  {:error, %MoneyHub.Error{reason: :rate_limited, retry_after: seconds}} ->
    # back off and retry after seconds

  {:error, %MoneyHub.Error{reason: :api_error, status: status, code: code}} ->
    Logger.error("Moneyhub API error #{status}: #{code}")
end
```

## Documentation

Full module documentation: <https://hexdocs.pm/money_hub>.

## License

MIT
