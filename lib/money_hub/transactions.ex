defmodule MoneyHub.Transactions do
  @moduledoc """
  Transaction data: list and fetch transactions, with date-range and
  account filtering, and manual category correction.

  See [Transactions](https://docs.moneyhubenterprise.com/docs/transactions)
  and [Categorising Transactions](https://docs.moneyhubenterprise.com/docs/categorising-transactions).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type transaction :: map()

  @doc """
  Lists transactions for the user identified by `token`.

  ## Options

    * `:account_id` - filter to a single account.
    * `:from_date` / `:to_date` - ISO 8601 date strings (`"2024-01-01"`).
    * `:category` - filter by category id.
    * `:limit` / `:offset` - pagination.
  """
  @spec list(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, [transaction()]} | {:error, Error.t()}
  def list(config, token, opts \\ []) do
    query =
      %{}
      |> maybe_put("accountId", Keyword.get(opts, :account_id))
      |> maybe_put("fromDate", Keyword.get(opts, :from_date))
      |> maybe_put("toDate", Keyword.get(opts, :to_date))
      |> maybe_put("category", Keyword.get(opts, :category))
      |> maybe_put("limit", Keyword.get(opts, :limit))
      |> maybe_put("offset", Keyword.get(opts, :offset))

    case Client.request(config,
           method: :get,
           path: "/transactions",
           token: token,
           query: query
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc """
  Creates a single manual transaction (for a manual, non-bank-connected
  account). `attrs` typically includes `"accountId"`, `"amount"`,
  `"description"`, and `"date"`.
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) ::
          {:ok, transaction()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/transactions",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Creates multiple manual transactions in a single call. `transactions` is
  a list of the same shape accepted by `create/3`.
  """
  @spec create_many(MoneyHub.Config.t(), String.t(), [map()]) ::
          {:ok, [transaction()]} | {:error, Error.t()}
  def create_many(config, token, transactions) when is_list(transactions) do
    case Client.request(config,
           method: :post,
           path: "/transactions",
           token: token,
           json: %{"transactions" => transactions}
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single transaction by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, transaction()} | {:error, Error.t()}
  def get(config, token, transaction_id) when is_binary(transaction_id) do
    case Client.request(config,
           method: :get,
           path: "/transactions/#{transaction_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Updates arbitrary attributes on a transaction. Use `update_category/4`
  for the common case of just correcting the category.
  """
  @spec update(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, transaction()} | {:error, Error.t()}
  def update(config, token, transaction_id, attrs)
      when is_binary(transaction_id) and is_map(attrs) do
    case Client.request(config,
           method: :patch,
           path: "/transactions/#{transaction_id}",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Corrects a transaction's category, recording the user's override (and
  training future automatic categorisation for similar transactions).
  """
  @spec update_category(MoneyHub.Config.t(), String.t(), String.t(), String.t()) ::
          {:ok, transaction()} | {:error, Error.t()}
  def update_category(config, token, transaction_id, category_id)
      when is_binary(transaction_id) and is_binary(category_id) do
    update(config, token, transaction_id, %{"category" => category_id})
  end

  @doc "Deletes a manual transaction (one created via `create/3` or `create_many/3`)."
  @spec delete(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete(config, token, transaction_id) when is_binary(transaction_id) do
    case Client.request(config,
           method: :delete,
           path: "/transactions/#{transaction_id}",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end

  @doc """
  Splits a transaction into multiple parts, each with its own amount and
  category - for example splitting a supermarket trip into "groceries" and
  "household".

  `splits` is a list of `%{"amount" => amount, "category" => category_id}`
  maps. See
  [Transaction Splits](https://docs.moneyhubenterprise.com/docs/transaction-splits-via-api).
  """
  @spec split(MoneyHub.Config.t(), String.t(), String.t(), [map()]) ::
          {:ok, transaction()} | {:error, Error.t()}
  def split(config, token, transaction_id, splits)
      when is_binary(transaction_id) and is_list(splits) do
    case Client.request(config,
           method: :post,
           path: "/transactions/#{transaction_id}/splits",
           token: token,
           json: %{"splits" => splits}
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists the current splits on a transaction."
  @spec list_splits(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def list_splits(config, token, transaction_id) when is_binary(transaction_id) do
    case Client.request(config,
           method: :get,
           path: "/transactions/#{transaction_id}/splits",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Replaces a transaction's splits with a new set."
  @spec update_splits(MoneyHub.Config.t(), String.t(), String.t(), [map()]) ::
          {:ok, transaction()} | {:error, Error.t()}
  def update_splits(config, token, transaction_id, splits)
      when is_binary(transaction_id) and is_list(splits) do
    case Client.request(config,
           method: :patch,
           path: "/transactions/#{transaction_id}/splits",
           token: token,
           json: %{"splits" => splits}
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Removes all splits from a transaction, merging it back into a single line."
  @spec delete_splits(MoneyHub.Config.t(), String.t(), String.t()) ::
          :ok | {:error, Error.t()}
  def delete_splits(config, token, transaction_id) when is_binary(transaction_id) do
    case Client.request(config,
           method: :delete,
           path: "/transactions/#{transaction_id}/splits",
           token: token
         ) do
      {:ok, _response} -> :ok
      error -> error
    end
  end

  @doc "Lists file attachments (e.g. receipts) attached to a transaction."
  @spec list_files(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def list_files(config, token, transaction_id) when is_binary(transaction_id) do
    case Client.request(config,
           method: :get,
           path: "/transactions/#{transaction_id}/files",
           token: token
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
