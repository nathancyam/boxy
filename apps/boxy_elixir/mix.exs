defmodule BoxyElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :boxy_elixir,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {BoxyElixir.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
      {:grpcbox, "~> 0.15.0"},
      {:chatterbox,
       git: "https://github.com/tsloughter/chatterbox.git", tag: "v0.12.0", override: true},
      {:boxy_erlang, in_umbrella: true, manager: :rebar3}
    ]
  end
end
