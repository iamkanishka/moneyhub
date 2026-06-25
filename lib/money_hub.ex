defmodule MoneyHub do
  @moduledoc """
  A client for the [Moneyhub Open Finance API](https://docs.moneyhubenterprise.com/).

  Moneyhub provides three core capabilities, each with a corresponding
  group of modules in this library:

    * **Data Aggregation (AIS)** - connect a user's bank accounts and read
      balances/transactions: `MoneyHub.Accounts`, `MoneyHub.Transactions`,
      `MoneyHub.Connections`, `MoneyHub.Categories`,
      `MoneyHub.Counterparties`, `MoneyHub.GlobalCounterparties`,
      `MoneyHub.Beneficiaries`, `MoneyHub.Holdings`,
      `MoneyHub.RegularTransactions`, `MoneyHub.SavingsGoals`,
      `MoneyHub.SpendingGoals`, `MoneyHub.SpendingAnalysis`,
      `MoneyHub.RentalRecords`, `MoneyHub.Affordability`,
      `MoneyHub.StandardFinancialStatements`,
      `MoneyHub.NotificationThresholds`, `MoneyHub.Statements`,
      `MoneyHub.Tax`, `MoneyHub.Projects`, `MoneyHub.ConsentHistory`,
      `MoneyHub.Discovery`, `MoneyHub.BankIcons`, `MoneyHub.ResellerCheck`,
      `MoneyHub.Users`, `MoneyHub.ScimUsers`.
    * **Payments (PIS)** - initiate single payments, recurring (VRP)
      sweeps, standing orders, bulk pay files, and shareable pay links:
      `MoneyHub.Payees`, `MoneyHub.Payments`,
      `MoneyHub.RecurringPayments`, `MoneyHub.StandingOrders`,
      `MoneyHub.PayLinks`, `MoneyHub.PayFile`.
    * **Webhooks** - receive and verify asynchronous event notifications:
      `MoneyHub.Webhooks`.

  All of the above sit on top of `MoneyHub.Auth`, which implements
  Moneyhub's OpenID Connect flows (Pushed Authorisation Requests,
  `private_key_jwt` client authentication, authorisation code exchange,
  and `client_credentials` tokens for ongoing access).

  ## Configuration

  Build a `MoneyHub.Config` once (typically at application boot, or
  per-tenant if you serve multiple Moneyhub clients) and pass it to every
  call:

      config = MoneyHub.Config.new!(
        environment: :sandbox,
        client_id: System.fetch_env!("MONEYHUB_CLIENT_ID"),
        jwk: MoneyHub.Auth.PrivateKeyJWT.load_jwk!(System.fetch_env!("MONEYHUB_PRIVATE_KEY_PATH")),
        jwk_kid: System.fetch_env!("MONEYHUB_KEY_ID"),
        redirect_uri: "https://myapp.example.com/moneyhub/callback"
      )

  This library starts its own supervised `Finch` connection pool
  (MoneyHub.Finch) under MoneyHub.Application - no extra setup is
  required beyond adding `:money_hub` to your application's dependencies.
  Configure pool sizing via:

      config :money_hub, :finch_pools, %{default: [size: 25, count: 1]}

  ## End-to-end example: connect a bank account, then read transactions

      alias MoneyHub.{Auth, Claims, Scopes, Accounts, Transactions}
      alias MoneyHub.Auth.IdToken

      # 1. Build an authorisation URL for a new user
      claims = Claims.new() |> Claims.put_sub()

      {:ok, %{url: url}} =
        Auth.pushed_authorisation_request(config, scope: Scopes.ais_offline(), claims: claims)

      # 2. Redirect the user's browser to `url`. They authenticate at
      #    their bank and are redirected back to your `redirect_uri` with
      #    `?code=...&state=...`.

      # 3. Exchange the code for tokens and verify the id_token
      {:ok, tokens} = Auth.exchange_code(config, code)
      {:ok, id_claims} = IdToken.verify(tokens.id_token, config)
      user_id = id_claims["sub"]

      # 4. From now on, fetch fresh data tokens for this user as needed
      {:ok, data_token} = Auth.token_for_user(config, user_id)
      {:ok, accounts} = Accounts.list(config, data_token.access_token)
      {:ok, transactions} = Transactions.list(config, data_token.access_token, account_id: hd(accounts)["id"])

  See the `MoneyHub.Auth`, `MoneyHub.Claims`, and `MoneyHub.Scopes` module
  docs for the full range of supported flows, including single-use (no
  persistent user) connections, payments, VRP, and standing orders.
  """
end
