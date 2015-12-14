Code.require_file "./bootstrap/skylight_bootstrap.ex"

defmodule Mix.Tasks.Compile.Skylight do
  use Mix.Task

  @shortdoc "Fetches Skylight binaries and compiles native C code"

  def run(_args) do
    if SkylightBootstrap.artifacts_already_exist? do
      :ok = SkylightBootstrap.extract_and_move()
      compile_c_code()
    else
      # TODO make this message way nicer
      Mix.shell.error "Run `mix skylight.fetch`"
    end

    :ok
  end

  defp compile_c_code do
    Mix.shell.info "Compiling native C code..."
    check_executable!("make")
    {result, _errcode} = System.cmd("make", ["priv/skylight_nif.so"], stderr_to_stdout: true)
    IO.binwrite(result)
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
     aliases: [test: "test --no-start"],
     elixirc_paths: elixirc_paths(),
     deps: deps]
  end

  def application do
    [applications: [:logger, :crypto, :uuid],
     env: [version: "0.8.1",
           lazy_start: true,
           auth_url: "https://auth.skylight.io/agent",
           validate_authentication: false],
     mod: {Skylight, []}]
  end

  defp elixirc_paths do
    if SkylightBootstrap.artifacts_already_exist? do
      ~w(lib bootstrap/mix/tasks)
    else
      ~w(bootstrap/mix/tasks)
    end
  end

  defp deps do
    [{:uuid, "~> 1.1"},
     {:plug, ">= 1.0.0", optional: true},
     {:cowboy, ">= 1.0.0", optional: true},
     {:ecto, ">= 1.0.0", optional: true},
     {:cowboy, ">= 1.0.0", only: :test},
     {:ex_doc, "~> 0.10", only: :docs}]
  end
end
