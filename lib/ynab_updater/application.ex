defmodule YnabUpdater.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    tasks = [
      %YnabUpdater.DummyTask{name: "slow"},
      YnabUpdater.Tasks.SyncTrackingBudget.new(
        Application.get_env(:ynab_updater, :api_key),
        Application.get_env(:ynab_updater, :main_budget),
        Application.get_env(:ynab_updater, :tracking_budget),
        Application.get_env(:ynab_updater, :tracking_account))
    ]

    children = [
      {YnabUpdater.Scheduler, tasks}
    ]

    opts = [strategy: :one_for_one, name: YnabUpdater.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
