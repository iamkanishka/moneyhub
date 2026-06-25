defmodule MoneyHub.Accounts do
  @moduledoc """
  Account data: list, fetch, update, and delete accounts; manual account
  creation; account balances.

  Accounts represent a single product at a financial institution
  (current account, savings, card, loan, mortgage, investment, pension, or
  property) connected via open banking, screen-scraping, or entered
  manually. See
  [Accounts](https://docs.moneyhubenterprise.com/docs/accounts) and
  [Bank Connection Response](https://docs.moneyhubenterprise.com/docs/bank-connection-response)
  for the full field reference.

  Reading account identifiers (sort code, account number, IBAN, PAN)
  requires the `accounts_details:read` scope in addition to
  `accounts:read` - see
  [Sensitive Information](https://docs.moneyhubenterprise.com/docs/sensitive-information).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type account :: map()

  @doc """
  Lists accounts for the user identified by `token`.

  ## Options

    * `:connection_id` - filter to accounts from a single connection.
    * `:account_type` - filter by account type (`"cash"`, `"savings"`,
      `"card"`, `"investment"`, `"loan"`, `"mortgage"`, `"pension"`,
      `"properties"`).
  """
  @spec list(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, [account()]} | {:error, Error.t()}
  def list(config, token, opts \\ []) do
    query =
      %{}
      |> maybe_put("connectionId", Keyword.get(opts, :connection_id))
      |> maybe_put("accountType", Keyword.get(opts, :account_type))

    case Client.request(config, method: :get, path: "/accounts", token: token, query: query) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single account by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, account()} | {:error, Error.t()}
  def get(config, token, account_id) when is_binary(account_id) do
    case Client.request(config,
           method: :get,
           path: "/accounts/#{account_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Creates a manual account (one not backed by a live bank connection) -
  for example a `properties:residential` valuation entry or an
  off-platform cash account. `attrs` is the account payload.
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) ::
          {:ok, account()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/accounts",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Updates a manual account's attributes."
  @spec update(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, account()} | {:error, Error.t()}
  def update(config, token, account_id, attrs) when is_binary(account_id) and is_map(attrs) do
    case Client.request(config,
           method: :patch,
           path: "/accounts/#{account_id}",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Deletes an account."
  @spec delete(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete(config, token, account_id) when is_binary(account_id) do
    case Client.request(config,
           method: :delete,
           path: "/accounts/#{account_id}",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end

  @doc """
  Lists historical balance snapshots for an account.

  See [Historical Balances](https://docs.moneyhubenterprise.com/docs/historical-balances).
  """
  @spec balances(MoneyHub.Config.t(), String.t(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def balances(config, token, account_id, opts \\ []) when is_binary(account_id) do
    query =
      %{}
      |> maybe_put("fromDate", Keyword.get(opts, :from_date))
      |> maybe_put("toDate", Keyword.get(opts, :to_date))

    case Client.request(config,
           method: :get,
           path: "/accounts/#{account_id}/balances",
           token: token,
           query: query
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc """
  Adds a new balance entry for a manual account (one created via
  `create/3`). Not applicable to accounts backed by a live bank
  connection, whose balances are populated automatically by sync.
  """
  @spec add_balance(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def add_balance(config, token, account_id, attrs)
      when is_binary(account_id) and is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/accounts/#{account_id}/balances",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Lists the standing orders the bank itself reports for an account (AIS
  read), as distinct from standing orders *created* via
  `MoneyHub.StandingOrders` (PIS write). Requires `accounts:read` plus
  either `standing_orders:read` or `standing_orders_detail:read`.
  """
  @spec standing_orders(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def standing_orders(config, token, account_id) when is_binary(account_id) do
    case Client.request(config,
           method: :get,
           path: "/accounts/#{account_id}/standing-orders",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc """
  Retrieves sync status/metadata for every account belonging to the user
  identified by `token`.
  """
  @spec syncs(MoneyHub.Config.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def syncs(config, token) do
    case Client.request(config, method: :get, path: "/accounts/syncs", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
