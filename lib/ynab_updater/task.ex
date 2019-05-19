defmodule YnabUpdater.Task do
  @moduledoc """
  Generic task behaviour.
  """
  defstruct([])

  @doc "Executes given task"
  @callback execute_task(%Task{}) :: {:ok, %Task{}} | {:error, any()}
  def execute_task(task) do
    module = task.__struct__
    apply(module, :execute_task, [task])
  end

  @doc "Calculates the next time the task should be executed"
  @callback calculate_next_run_at(%Task{}) :: DateTime.t | nil
  def calculate_next_run_at(task) do
    module = task.__struct__
    apply(module, :calculate_next_run_at, [task])
  end
end
