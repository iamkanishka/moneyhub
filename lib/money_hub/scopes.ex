defmodule MoneyHub.Scopes do
  @moduledoc """
  Known Moneyhub OAuth2 scopes, grouped by purpose.

  Scopes are plain strings on the wire (space-delimited in the
  `scope` authorisation parameter) - this module exists so call sites can
  reference `MoneyHub.Scopes.accounts_read()` instead of repeating
  `"accounts:read"` everywhere, and to give a single place documenting what
  each scope unlocks.

  Combine scopes with `join/1`:

      MoneyHub.Scopes.join([
        MoneyHub.Scopes.openid(),
        MoneyHub.Scopes.accounts_read(),
        MoneyHub.Scopes.transactions_read()
      ])
      #=> "openid accounts:read transactions:read"

  ## Bank connection (AIS) scopes

    * `openid/0` - required on every authorisation request.
    * `accounts_read/0` - read account summaries (balances, type, provider).
    * `accounts_details_read/0` - read sensitive account identifiers (sort
      code, account number, IBAN, PAN). Subject to additional approval.
    * `transactions_read/0` - read transaction history.
    * `offline_access/0` - request a refresh token for ongoing access.

  ## Payment (PIS) scopes

    * `payment/0` - required to create/execute a single immediate payment.
    * `payee_create/0` - required to create a payee ahead of payment.
    * `recurring_payment/0` - required for Variable Recurring Payments (VRP).
    * `standing_order/0` - required to create standing orders.

  ## Provider chooser scopes

    * `id_api/0` - shows API-based (live) providers in the bank chooser.
    * `id_test/0` - shows test/mock providers in the bank chooser.

  ## Identity / widget scopes

    * `widget_authentication/0` - required for embedded-component tenant
      user tokens.
  """

  @type t :: String.t()

  @spec openid() :: t()
  def openid, do: "openid"

  @spec accounts_read() :: t()
  def accounts_read, do: "accounts:read"

  @spec accounts_details_read() :: t()
  def accounts_details_read, do: "accounts_details:read"

  @spec transactions_read() :: t()
  def transactions_read, do: "transactions:read"

  @spec offline_access() :: t()
  def offline_access, do: "offline_access"

  @spec payment() :: t()
  def payment, do: "payment"

  @spec payee_create() :: t()
  def payee_create, do: "payee:create"

  @spec recurring_payment() :: t()
  def recurring_payment, do: "recurring_payment"

  @spec standing_order() :: t()
  def standing_order, do: "standing_order"

  @spec id_api() :: t()
  def id_api, do: "id:api"

  @spec id_test() :: t()
  def id_test, do: "id:test"

  @spec widget_authentication() :: t()
  def widget_authentication, do: "widget_authentication"

  @doc """
  Joins a list of scopes into the space-delimited string expected by the
  `scope` authorisation parameter. Duplicates are removed; order of first
  appearance is preserved.
  """
  @spec join([t()]) :: String.t()
  def join(scopes) when is_list(scopes) do
    scopes
    |> Enum.uniq()
    |> Enum.join(" ")
  end

  @doc """
  The minimal scope set for a one-time or ongoing AIS (account
  aggregation) connection: `openid accounts:read transactions:read`.
  """
  @spec ais() :: String.t()
  def ais, do: join([openid(), accounts_read(), transactions_read()])

  @doc """
  `ais/0` plus `offline_access`, for connections that should be refreshable
  without the user re-authenticating from scratch.
  """
  @spec ais_offline() :: String.t()
  def ais_offline, do: join([openid(), accounts_read(), transactions_read(), offline_access()])

  @doc """
  The minimal scope set to create and execute a single immediate payment:
  `openid payment payee:create`.
  """
  @spec payments() :: String.t()
  def payments, do: join([openid(), payment(), payee_create()])
end
