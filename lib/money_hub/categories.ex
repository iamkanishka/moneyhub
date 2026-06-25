defmodule MoneyHub.Categories do
  @moduledoc """
  The Moneyhub category and category-group taxonomy used to classify
  transactions, plus business/personal categorisation-as-a-service for
  data not connected through Moneyhub.

  See [Categories and Category Groups](https://docs.moneyhubenterprise.com/docs/categories-and-category-groups)
  and [Categorisation as a Service](https://docs.moneyhubenterprise.com/docs/categorisation-as-a-service).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type category :: map()

  @doc """
  Lists all categories and category groups.

  ## Options

    * `:type` - `:personal` (default) or `:business`, selecting which
      taxonomy to return.
  """
  @spec list(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, [category()]} | {:error, Error.t()}
  def list(config, token, opts \\ []) do
    type = Keyword.get(opts, :type, :personal)

    case Client.request(config,
           method: :get,
           path: "/categories",
           token: token,
           query: %{"type" => Atom.to_string(type)}
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single category by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, category()} | {:error, Error.t()}
  def get(config, token, category_id) when is_binary(category_id) do
    case Client.request(config,
           method: :get,
           path: "/categories/#{category_id}",
           token: token
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Creates a custom category, in addition to Moneyhub's built-in taxonomy.
  `attrs` typically includes `"name"` and the parent `"categoryGroup"`.
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) ::
          {:ok, category()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config, method: :post, path: "/categories", token: token, json: attrs) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists all category groups (the parent grouping for individual categories)."
  @spec list_groups(MoneyHub.Config.t(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_groups(config, token) do
    case Client.request(config, method: :get, path: "/category-groups", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc """
  Categorises arbitrary transaction descriptions without requiring a live
  bank connection ("categorisation as a service"). `transactions` is a
  list of maps with at least a `"description"` key (and ideally `"amount"`
  for better accuracy).
  """
  @spec categorise(MoneyHub.Config.t(), String.t(), [map()]) ::
          {:ok, [map()]} | {:error, Error.t()}
  def categorise(config, token, transactions) when is_list(transactions) do
    case Client.request(config,
           method: :post,
           path: "/categorisation",
           token: token,
           json: %{"transactions" => transactions}
         ) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end
end
