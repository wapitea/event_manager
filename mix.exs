defmodule EventManager.MixProject do
  use Mix.Project

  def project do
    [
      app: :event_manager,
      version: "0.2.2",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "EventManager",
      description: "A simple event manager based on elixir's Registry.",
      source_url: "https://github.com/wapitea/event_manager",
      docs: [
        main: "readme",
        # logo: "path/to/logo.png",
        extras: ["README.md"]
      ],
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Alexandre Lepretre", "Antoine Pecatikov"],
      licenses: ["GNU GPLv3"],
      links: %{"Github" => "https://github.com/wapitea/event_manager"},
      name: "event_manager"
    ]
  end
end
