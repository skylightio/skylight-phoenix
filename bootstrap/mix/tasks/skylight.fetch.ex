defmodule Mix.Tasks.Skylight.Fetch do
  use Mix.Task

  @shortdoc "TODO"

  @moduledoc "TODO"

  def run(_args) do
    :ok = SkylightBootstrap.fetch()
  end
end
