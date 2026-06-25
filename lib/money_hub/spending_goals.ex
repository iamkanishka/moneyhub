defmodule MoneyHub.SpendingGoals do
  @moduledoc """
  Spending and income goals: budgeting targets scoped to a category and
  date range (for example "spend less than £500/month on groceries").

  See [Spending and Income Goals](https://docs.moneyhubenterprise.com/docs/spending-and-income-goals).
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type goal :: map()

  @doc """
  Creates a spending/income goal. `attrs` typically includes `"category"`,
  `"targetAmount"`, and `"period"` (e.g. `"monthly"`).
  """
  @spec create(MoneyHub.Config.t(), String.t(), map()) :: {:ok, goal()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config,
           method: :post,
           path: "/spending-goals",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Lists spending/income goals for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [goal()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/spending-goals", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single spending/income goal, including current progress."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) :: {:ok, goal()} | {:error, Error.t()}
  def get(config, token, goal_id) when is_binary(goal_id) do
    case Client.request(config, method: :get, path: "/spending-goals/#{goal_id}", token: token) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Deletes a spending/income goal."
  @spec delete(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete(config, token, goal_id) when is_binary(goal_id) do
    case Client.request(config, method: :delete, path: "/spending-goals/#{goal_id}", token: token) do
      {:ok, _response} -> :ok
      error -> error
    end
  end
end
