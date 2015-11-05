defmodule Skylight.TestHelpers do
  @token System.get_env("DIREWOLF_PHOENIX_TOKEN") || Mix.raise("""
  Skylight auth token not found. Set the $DIREWOLF_PHOENIX_TOKEN env variable to
  a valid Skylight token.
  """)

  def auth_token() do
    @token
  end
end

ExUnit.start()
