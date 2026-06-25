defmodule MoneyHub.SavingsGoals do
  @moduledoc """
  Savings goals: user-defined targets tracked against the combined balance
  of one or more accounts, surfacing progress as both an amount and a
  percentage.

  See [Spending and Income Goals](https://docs.moneyhubenterprise.com/docs/spending-and-income-goals)
  and the savings-goals recipe.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type goal :: map()

  @doc """
  Creates a savings goal. `attrs` typically includes `"name"`,
  `"targetAmount"`, and `"accountIds"` (the account(s) whose combined
  balance counts toward the goal).
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) :: {:ok, goal()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/savings-goals",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists savings goals for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [goal()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/savings-goals", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single savings goal, including current progress."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) :: {:ok, goal()} | {:error, Error.t()}
  def get(config, token, goal_id) when is_binary(goal_id) do
    case Client.request(config, method: :get, path: "/savings-goals/#{goal_id}", token: token) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Updates a savings goal's attributes (e.g. target amount, name, accounts)."
  @spec update(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, goal()} | {:error, Error.t()}
  def update(config, token, goal_id, attrs) when is_binary(goal_id) and is_map(attrs) do
    case Client.request(config,
           method: :patch,
           path: "/savings-goals/#{goal_id}",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Deletes a savings goal."
  @spec delete(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete(config, token, goal_id) when is_binary(goal_id) do
    case Client.request(config, method: :delete, path: "/savings-goals/#{goal_id}", token: token) do
      {:ok, _response} -> :ok
      error -> error
    end
  end
end
