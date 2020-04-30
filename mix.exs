defmodule SimpleRestView.MixProject do
  use Mix.Project

  def project do
    [
      app: :simple_rest_view,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),

      name: "SimpleRestView",
      source_url: "https://github.com/SuseljJan/simple_rest_view"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
    ]
  end

  defp description do
    """
    Library to help with writing concise views in Phoenix REST projects
    """
  end

  def package do
    [
      maintainers: ["Jan Sušelj"],
      links: %{"GitHub" => "https://github.com/SuseljJan/simple_rest_view"},
      files: [
        "lib/simple_rest_view.ex",
        "mix.exs",
        "README.md"
      ]
    ]
  end
end
