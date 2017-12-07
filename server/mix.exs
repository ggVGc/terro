defmodule Terro.Mixfile do
  use Mix.Project

  def project do
    [app: :terro,
     version: "0.0.1",
     elixir: "~> 1.5.1",
     elixirc_paths: ["lib", "web"],
     compilers: [:phoenix] ++ Mix.compilers,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [mod: {Terro, []},
     applications: [:phoenix, :phoenix_html, :cowboy, :logger, :postgrex]]
  end

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps() do
    [{:phoenix, "~> 1.3.0"},
     {:phoenix_html, "~> 2.5"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:postgrex, "~> 0.13.3"},
     {:cowboy, "~> 1.0.4"},
     {:graphmath, "~> 1.0.2" }]
  end
end
