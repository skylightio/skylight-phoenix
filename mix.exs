defmodule Mix.Tasks.Compile.Skylight do
  use Mix.Task

  @shortdoc "Compiles the native C code for Skylight"

  def run(_args) do
    Mix.shell.info "Compiling native C code..."
    check_executable!("make")
    System.cmd("make", ["priv/skylight_nif.so"])
  end

  defp check_executable!(exec) do
    unless System.find_executable(exec) do
      Mix.raise "`#{exec}` not found in path."
    end
  end
end

defmodule Skylight.Mixfile do
  use Mix.Project

  def project do
    [app: :skylight,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     compilers: [:skylight] ++ Mix.compilers,
     deps: deps]
  end

  def application do
    [applications: [:logger, :crypto],
     mod: {Skylight, []}]
  end

  defp deps do
    [{:uuid, "~> 1.1"},
     {:plug, ">= 1.0.0", optional: true},
     {:cowboy, ">= 1.0.0", optional: true},
     {:ex_doc, "~> 0.10", only: :docs}]
  end
end
