defmodule PlEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :pl_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    case Mix.env() do
      :test ->
        [extra_applications: [:logger]]

      _ ->
        [
          extra_applications: [:logger],
          mod: {PlEx.Application, []}
        ]
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.18"},
      {:jason, "~> 1.4"},
      {:jose, "~> 1.11"},
      {:open_api_spex, "~> 3.6"},
      {:plug, "~> 1.15"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end
end
