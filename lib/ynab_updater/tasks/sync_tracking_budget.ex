defmodule YnabUpdater.Tasks.SyncTrackingBudget do
  @moduledoc """
  Task that fetches budget information from one budget,
  converts the currency to match the main budget and
  posts a transaction to an account in the main budget
  that represents the secondary budgets full net worth.
  """
  @behaviour YnabUpdater.Task
  defstruct access_token: nil, main_budget: nil, tracked_budget: nil, tracked_account: nil, last_run_at: nil, accounts: nil, accounts_server_knowledge: nil

  alias YnabApi.Models.Account
  alias YnabApi.Models.Budget

  @doc """
  Creates a new instance of SyncTrackingBudget task.
  """
  def new(access_token, main_budget, tracked_budget, tracked_account) do
    %__MODULE__{
      access_token: access_token,
      main_budget: get_budget_information!(access_token, main_budget),
      tracked_budget: get_budget_information!(access_token, tracked_budget),
      tracked_account: check_account!(access_token, main_budget, tracked_account)
    }
  end

  # Task implementation

  @impl YnabUpdater.Task
  def execute_task(task) do
    IO.puts "task"
    IO.inspect task
    now = DateTime.utc_now()

    main_currency_format = task.main_budget.currency_format.iso_code
    tracked_currency_format = task.tracked_budget.currency_format.iso_code

    with {:ok, accounts} <- YnabApi.get_accounts(task.access_token, task.tracked_budget.id),
         balance <- Enum.reduce(accounts, 0, fn e, acc -> acc + e.balance end),
         {:ok, tracked_account} <-
           YnabApi.get_account(task.access_token, task.main_budget.id, task.tracked_account),
         {:ok, rate} <- get_exchange_rate(main_currency_format, tracked_currency_format)
    do
      rate_adjusted_balance = trunc(div(round(balance / rate), 10) * 10)
      balance_difference = rate_adjusted_balance - tracked_account.balance

      transaction = %{
        account_id: task.tracked_account,
        date: Date.to_iso8601(Date.utc_today()),
        amount: balance_difference,
        #"payee_id": "string",
        #"payee_name": "string",
        #"category_id": "string",
        memo: "Automatically created based on another budgets net worth",
        cleared: "cleared",
        approved: false
        #import_id: "string"
      }
      url = "https://api.youneedabudget.com/v1/budgets/#{task.main_budget.id}/transactions"
      headers = [
        "Authorization": "Bearer #{task.access_token}",
        "Accept": "Application/json; Charset=utf-8",
        "Content-Type": "application/json"
      ]

      with {:ok, json} <- Jason.encode(%{ transaction: transaction }),
           {:ok, response = %HTTPoison.Response{status_code: status_code, body: body}} <-
             HTTPoison.post(url, json, headers),
           {:ok, response} <- Jason.decode(body)
      do
        IO.puts "response"
        IO.inspect response
      else
        {:error, error} ->
          throw error
        other ->
          throw other
      end
    else
      {:error, error} ->
        throw error
      other ->
        throw other
    end

    {:ok, %{task | last_run_at: now}}
  end

  @impl YnabUpdater.Task
  def calculate_next_run_at(task) do
    if task.last_run_at == nil do
      DateTime.utc_now()
    else
      DateTime.add(task.last_run_at, 10 * 60)
    end
  end

  # Helper functions

  defp get_budget_information!(access_token, budget_id) when is_binary(budget_id) do
    {:ok, budget_settings} = YnabApi.get_budget_settings(access_token, budget_id)

    %{
      id: budget_id,
      currency_format: budget_settings.currency_format
    }
  end

  defp check_account!(access_token, budget_id, account_id) do
    {:ok, %Account{}} = YnabApi.get_account(access_token, budget_id, account_id)
    account_id
  end

  defp get_exchange_rate(base, comparison) do
    url = "https://api.exchangeratesapi.io/latest?base=#{base}&symbols=#{comparison}"

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.get(url),
         {:ok, parsed_body} <- Jason.decode(body, keys: :strings),
         {:ok, rates} <- Map.fetch(parsed_body, "rates"),
         {:ok, rate} <- Map.fetch(rates, comparison)
    do
      {:ok, rate}
    else
      {:ok, response = %HTTPoison.Response{}} ->
        {:error, {:unexpected_response, response}}
      {:error, error} ->
        {:error, error}
      :error ->
        {:error, :unstructured_response}
      other ->
        {:error, {:error_clause_not_matched, other}}
    end
  end
end
