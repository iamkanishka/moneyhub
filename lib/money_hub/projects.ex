defmodule MoneyHub.Projects do
  @moduledoc """
  Projects: a user-defined grouping construct (similar in spirit to a
  manual account) that can be created, read, updated, and deleted via the
  API. Projects created via the API can be deleted directly; projects
  created as part of a bank connection can only be removed by removing
  the connection.
  """

  alias MoneyHub.Client
  alias MoneyHub.Error

  @type project :: map()

  @doc "Lists projects for the user identified by `token`."
  @spec list(MoneyHub.Config.t(), String.t()) :: {:ok, [project()]} | {:error, Error.t()}
  def list(config, token) do
    case Client.request(config, method: :get, path: "/projects", token: token) do
      {:ok, response} -> {:ok, Client.unwrap_list(response.body)}
      error -> error
    end
  end

  @doc "Fetches a single project by id."
  @spec get(MoneyHub.Config.t(), String.t(), String.t()) ::
          {:ok, project()} | {:error, Error.t()}
  def get(config, token, project_id) when is_binary(project_id) do
    case Client.request(config, method: :get, path: "/projects/#{project_id}", token: token) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Creates a project for the user identified by `token`."
  @spec create(MoneyHub.Config.t(), String.t(), map()) :: {:ok, project()} | {:error, Error.t()}
  def create(config, token, attrs) when is_map(attrs) do
    case Client.request(config, method: :post, path: "/projects", token: token, json: attrs) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc "Updates a project's attributes."
  @spec update(MoneyHub.Config.t(), String.t(), String.t(), map()) ::
          {:ok, project()} | {:error, Error.t()}
  def update(config, token, project_id, attrs) when is_binary(project_id) and is_map(attrs) do
    case Client.request(config,
           method: :patch,
           path: "/projects/#{project_id}",
           token: token,
           json: attrs
         ) do
      {:ok, response} -> {:ok, response.body}
      error -> error
    end
  end

  @doc """
  Deletes a project. Only works for projects created via `create/3` -
  projects originating from a bank connection are removed by deleting the
  connection (see `MoneyHub.Connections.delete/3`).
  """
  @spec delete(MoneyHub.Config.t(), String.t(), String.t()) :: :ok | {:error, Error.t()}
  def delete(config, token, project_id) when is_binary(project_id) do
    case Client.request(config, method: :delete, path: "/projects/#{project_id}", token: token) do
      {:ok, _response} -> :ok
      error -> error
    end
  end
end
