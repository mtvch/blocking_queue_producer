defmodule BlockingQueueProducer.MixProject do
  use Mix.Project

  def project do
    [
      app: :blocking_queue_producer,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/mtvch/blocking_queue_producer",
      description: "GenStage producer with back pressure for push model",
      package: package(),
      deps: deps()
    ]
  end

    defp package do
    [
      maintainers: ["Matvey Karpov"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mtvch/blocking_queue_producer"}
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:gen_stage, "~> 1.0"},
      {:telemetry, "~> 1.2"},
      {:prom_ex, "~> 1.9"}
    ]
  end
end
