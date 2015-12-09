Code.require_file "./bootstrap/skylight_bootstrap.ex", File.cwd!()

defmodule Mix.Tasks.Skylight.Fetch do
  use Mix.Task

  @shortdoc "TODO"

  @moduledoc "TODO"

  def run(_args) do
    SkylightBootstrap.fetch()
    :ok
  end
end
