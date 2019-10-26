defmodule YnabUpdater.DummyTask do
  @behaviour YnabUpdater.Task
  defstruct interval: 10, unit: :second, name: 'default name'

  @impl YnabUpdater.Task
  def execute_task(task) do
    IO.puts "Ran dummy task #{task.name}"
    {:ok, task}
  end

  @impl YnabUpdater.Task
  def calculate_next_run_at(task) do
    now = DateTime.utc_now
    DateTime.add(now, task.interval, task.unit)
  end

end
