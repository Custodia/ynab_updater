defmodule YnabUpdater.Scheduler do
  use GenServer
  alias YnabUpdater.Task

  def start_link(tasks) when is_list(tasks) do
    GenServer.start_link(__MODULE__, tasks)
  end

  # GenServer Callbacks

  @impl GenServer
  def init(tasks) do
    {:ok, nil, {:continue, {:init, tasks}}}
  end

  @impl GenServer
  def handle_continue({:init, tasks}, nil) do
    tasks = tasks
    |> Enum.map(fn task ->
      %{
        run_at: Task.calculate_next_run_at(task),
        task: task
      }
    end)
    |> Enum.filter(fn %{ run_at: run_at } -> run_at != nil end)

    state = schedule_work(%{ timer_ref: nil, tasks: tasks })
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:do_work, state = %{ tasks: tasks }) do
    now = DateTime.utc_now()
    new_tasks = tasks
      |> Enum.map(fn task ->
        time_diff = DateTime.compare(now, task.run_at)
        if time_diff != :lt, do: handle_task!(task.task), else: task
      end)
      |> Enum.filter(fn %{ run_at: run_at } -> run_at != nil end)

    new_state = schedule_work(%{state | tasks: new_tasks})
    {:noreply, new_state}
  end

  # Helpers

  defp schedule_work(state = %{ timer_ref: timer_ref, tasks: [] }) do
    if timer_ref, do: Process.cancel_timer(timer_ref)
    %{ state | timer_ref: nil, tasks: [] }
  end
  defp schedule_work(state = %{ timer_ref: timer_ref, tasks: tasks }) do
    min_date_time = tasks
      |> Enum.reduce(fn acc, e ->
        if DateTime.compare(acc.run_at, e.run_at) == :gt, do: e, else: acc
      end)
      |> Map.fetch!(:run_at)

    now = DateTime.utc_now()
    ms_diff = DateTime.diff(now, min_date_time, :millisecond)

    if timer_ref, do: Process.cancel_timer(timer_ref)
    new_timer_ref = Process.send_after(self(), :do_work, max(1, ms_diff))

    %{ state | timer_ref: new_timer_ref }
  end

  defp handle_task!(task) do
    {:ok, task} = Task.execute_task(task)
    next_run_at = Task.calculate_next_run_at(task)
    %{ run_at: next_run_at, task: task }
  end
end
