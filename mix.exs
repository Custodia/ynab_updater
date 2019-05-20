defmodule YnabUpdater.MixProject do
  use Mix.Project

  def project do
    [
      app: :ynab_updater,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {YnabUpdater.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ynab_api, git: "https://github.com/Custodia/elixir-ynab-api.git"},
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.1"}
    ]
  end
end
