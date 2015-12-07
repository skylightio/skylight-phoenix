defmodule Mix.Tasks.Skylight.GenRepo do
  use Mix.Task

  require Mix.Generator

  @shortdoc "Generates a Skylight.Repo wrapper for an Ecto repository"

  @moduledoc """
  Generates a Skylight-aware wrapper for an Ecto repository.

  The Ecto repository you want to wrap must be passed explicitely using the
  `--repo` command-line argument (aliased to `-r` for brevity). The last part of
  the module name of this repository is stripped out and replaced with
  `Skylight.Repo` (e.g., `MyApp.Repo` becomes `MyApp.Skylight.Repo`).

  Assuming this command is run in the project directory for the `:my_app`
  application, then the new wrapper repository will be generated at
  `lib/my_app/skylight.repo.ex`.

  ## Usage

      mix skylight.gen_repo --repo MyApp.Repo

  """

  @template ~S"""
  defmodule <%= inspect @skylight_repo %> do
    use Skylight.Ecto.Repo, proxy_to: <%= inspect @existing_repo %>
  end
  """
  Mix.Generator.embed_template(:skylight_repo, @template)

  def run(args) do
    _ = Mix.Project.get!

    app           = Keyword.fetch!(Mix.Project.config, :app)
    existing_repo = find_repo_module(args)
    skylight_repo = skylight_repo_from_existing(existing_repo)
    path          = skylight_repo_path(app)

    write_to_file(path, skylight_repo_template([skylight_repo: skylight_repo,
                                                existing_repo: existing_repo]))
  end

  defp find_repo_module(args) do
    case OptionParser.parse(args, strict: [repo: :string], aliases: [r: :repo]) do
      {parsed, [], []} ->
        if repo = parsed[:repo] do
          Module.concat([repo])
        else
          Mix.raise "You have to pass the proxy repo you want to use with -r/--repo."
                     <> " See `mix help skylight.gen_repo`"
        end
      _ ->
        Mix.raise("Invalid arguments. See `mix help skylight.gen_repo`")
    end
  end

  defp skylight_repo_from_existing(existing_repo) do
    existing_repo                      # MyApp.Repo
    |> Module.split()                  # ["MyApp", "Repo"]
    |> Enum.drop(-1)                   # ["MyApp"]
    |> Kernel.++(["Skylight", "Repo"]) # ["MyApp", "Skylight", "Repo"]
    |> Module.concat()                 # MyApp.Skylight.Repo
  end

  defp skylight_repo_path(app) do
    Path.join [File.cwd!(), "lib", to_string(app), "skylight.repo.ex"]
  end

  defp write_to_file(path, contents) do
    Mix.Generator.create_directory(Path.dirname(path))
    Mix.Generator.create_file(path, contents)
  end
end
