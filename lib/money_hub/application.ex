defmodule MoneyHub.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: MoneyHub.Finch, pools: finch_pools()}
    ]

    opts = [strategy: :one_for_one, name: MoneyHub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp finch_pools do
    Application.get_env(:money_hub, :finch_pools, %{
      default: [size: 10, count: 1]
    })
  end
end
