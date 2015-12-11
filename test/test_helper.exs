defmodule Skylight.TestHelpers do
  @token System.get_env("DIREWOLF_PHOENIX_TOKEN") || Mix.raise("""
  Skylight auth token not found. Set the $DIREWOLF_PHOENIX_TOKEN env variable to
  a valid Skylight token.
  """)

  def auth_token() do
    @token
  end
end

defmodule SkylightBootstrap.TestHelpers do
  @fixtures_path "test/bootstrap/fixtures"

  def fixture_path(path) do
    @fixtures_path
    |> Path.join(path)
    |> Path.expand()
  end
end

Mix.shell(Mix.Shell.Process)

# The :skylight application won't start unless there's an :authentication key in
# its env, so we're manually putting that key in the environment here and then
# manually starting the application. Note that for this to work, we had to set
# up the "test" alias in mix.exs to run "test --no-start".
Application.put_env(:skylight, :authentication, Skylight.TestHelpers.auth_token())
Application.ensure_all_started(:skylight)

ExUnit.start()
