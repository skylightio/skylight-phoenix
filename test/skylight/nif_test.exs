defmodule Skylight.NIFTest do
  use ExUnit.Case
  alias Skylight.TestHelpers

  alias Skylight.NIF

  @libskylight_path "native/skylight_x86_64-darwin/libskylight.dylib"

  setup_all do
    :ok = NIF.load_libskylight(@libskylight_path)
  end

  test "hrtime/0" do
    hrtime = NIF.hrtime()
    assert is_integer(hrtime)
    assert hrtime > 1_000_000_000_000
  end

  test "instrumenter_new/1" do
    env = [
      "SKYLIGHT_AUTHENTICATION", TestHelpers.auth_token(),
    ]

    # For now, not raising is already a victory :)
    NIF.instrumenter_new(env)
  end

  test "lex_sql/1" do
    sql = "SELECT * FROM my_table WHERE my_field = 'my value'";
    assert NIF.lex_sql(sql) == "SELECT * FROM my_table WHERE my_field = ?";
  end
end
