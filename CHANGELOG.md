# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0] - Unreleased

### Added

- Initial release.
- OIDC authentication: Pushed Authorisation Requests (`MoneyHub.Auth`),
  `private_key_jwt` client assertions and request-object signing
  (`MoneyHub.Auth.PrivateKeyJWT`), `id_token` verification against
  Moneyhub's published JWKS (`MoneyHub.Auth.IdToken`, `MoneyHub.Auth.JWKS`),
  authorisation code exchange, `client_credentials` tokens for ongoing
  per-user access, and refresh tokens.
- Claims and scopes builders (`MoneyHub.Claims`, `MoneyHub.Scopes`) covering
  `sub`, `mh:con_id`, `mh:cat_type`, `mh:payment`, `mh:recurring_payment`,
  and `mh:standing_order`.
- Data Aggregation (AIS): `MoneyHub.Accounts`, `MoneyHub.Transactions`,
  `MoneyHub.Connections`, `MoneyHub.Users`, `MoneyHub.Categories`,
  `MoneyHub.Counterparties`, `MoneyHub.RegularTransactions`,
  `MoneyHub.RentalRecords`, `MoneyHub.SavingsGoals`,
  `MoneyHub.SpendingGoals`, `MoneyHub.SpendingAnalysis`,
  `MoneyHub.Affordability` (including an `await/4` polling helper),
  `MoneyHub.AuthRequests`.
- Payments (PIS): `MoneyHub.Payees`, `MoneyHub.Payments`,
  `MoneyHub.RecurringPayments` (VRP sweeps), `MoneyHub.StandingOrders`,
  `MoneyHub.PayLinks`.
- Webhook verification for both plain-JSON and signed-JWT delivery shapes
  (`MoneyHub.Webhooks`, `MoneyHub.Webhooks.Event`).
- Structured `MoneyHub.Error` results across the public API, with
  `:config_error`, `:network_error`, `:api_error`, `:rate_limited`,
  `:decode_error`, `:jwt_error`, and `:validation_error` reasons.
- Automatic retry with backoff for `429` (honouring `Retry-After`) and
  `5xx` responses, plus transient network errors, in `MoneyHub.Client`.
- `telemetry` events (`[:money_hub, :request, :start | :stop | :exception]`)
  around every data-API call.
- Full API surface pass: `MoneyHub.Beneficiaries`, `MoneyHub.Holdings`
  (ISIN-matched investment holdings), `MoneyHub.NotificationThresholds`,
  `MoneyHub.Projects`, `MoneyHub.Statements`, `MoneyHub.Tax`,
  `MoneyHub.StandardFinancialStatements`, `MoneyHub.GlobalCounterparties`,
  `MoneyHub.ConsentHistory`, `MoneyHub.ScimUsers`, `MoneyHub.PayFile`
  (bulk/batch payments), `MoneyHub.ResellerCheck`, `MoneyHub.BankIcons`,
  `MoneyHub.Discovery` (OIDC well-known configuration).
- Expanded existing modules with previously-missing endpoints:
  `Accounts.add_balance/4`, `Accounts.standing_orders/3`,
  `Accounts.syncs/2`; `Connections.sync/3` and connection-type filtered
  catalogs (`available_api/2`, `available_legacy/2`, `available_payments/2`,
  `available_test/2`); `Categories.get/3`, `Categories.create/3`,
  `Categories.list_groups/2`; `Transactions.create/3`,
  `Transactions.create_many/3`, `Transactions.update/4`,
  `Transactions.delete/3`, full splits CRUD, `Transactions.list_files/3`;
  `AuthRequests.list/2`, `AuthRequests.update/4`;
  `RecurringPayments.list/2`, `RecurringPayments.confirm_funds/4`;
  `Users.list_connections/3`, `Users.get_connection/4`,
  `Users.delete_connection/4`, `Users.list_syncs/3`.

### Fixed

- `RecurringPayments.sweep/4` posted to the wrong path
  (`/recurring-payments/{id}/payments` instead of the correct
  `/recurring-payments/{id}/pay`).
- Removed an explicit `:castore` dependency override that forced its
  `mix certdata` build task to compile, which fails on Erlang/OTP
  installations missing the `public_key` application's `include/`
  headers - notably common on Windows. The HTTP stack now relies on
  `:public_key.cacerts_get/0` (built into OTP 25+) for CA certificates
  instead, which is more portable.
