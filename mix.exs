Code.require_file("./bootstrap/skylight_bootstrap.ex")

defmodule Mix.Tasks.Compile.Skylight do
  use Mix.Task

  @shortdoc "Fetches Skylight binaries and compiles native C code"

  def run(_args) do
    result =
      with :ok <- ensure_artifacts_exist(),
           :ok <- SkylightBootstrap.extract_and_move(),
           do: compile_c_code()

    case result do
      {:error, message} ->
        Mix.shell().error(message)
        raise "Failed to compile Skylight: '#{message}'"

      _ ->
        result
    end
  end

  defp ensure_artifacts_exist do
    unless SkylightBootstrap.artifacts_already_exist?() do
      SkylightBootstrap.fetch()
    else
      :ok
    end
  end

  defp compile_c_code do
    Mix.shell().info("Compiling native C code...")
    check_executable!("make")
    {result, _errcode} = System.cmd("make", ["priv/skylight_nif.so"], stderr_to_stdout: true)
    IO.binwrite(result)
  end

  defp check_executable!(exec) do
    unless System.find_executable(exec) do
      Mix.raise("`#{exec}` not found in path.")
    end
  end
end

defmodule Skylight.Mixfile do
  use Mix.Project

  def project do
    [
      app: :skylight,
      version: "0.0.1",
      elixir: "~> 1.1",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: [:skylight] ++ Mix.compilers(),
      aliases: [test: "test --no-start"],
      elixirc_paths: elixirc_paths(),
      deps: deps()
    ]
  end

  def application do
    [
      applications: [:logger, :crypto, :uuid],
      env: [
        version: "0.8.1",
        lazy_start: true,
        auth_url: "https://auth.skylight.io/agent",
        validate_authentication: false
      ],
      mod: {Skylight, []}
    ]
  end

  defp elixirc_paths do
    ~w(lib bootstrap/mix/tasks)
  end

  defp deps do
    [
      {:uuid, "~> 1.1"},
      {:plug_cowboy, "~> 2.0"},
      {:ecto, "~> 3.0", optional: true},
      {:ex_doc, "~> 0.10", only: :docs},
      {:bypass, "~> 1.0", only: :test}
    ]
  end
end
