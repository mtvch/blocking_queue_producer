defmodule BlockingQueueProducer.MixProject do
  use Mix.Project

  def project do
    [
      app: :blocking_queue_producer,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_stage, "~> 1.0"},
      {:telemetry, "~> 1.2"},
      {:prom_ex, "~> 1.9"}
    ]
  end
end
