defmodule Skylight.NIFTest do
  use ExUnit.Case
  alias Skylight.TestHelpers

  alias Skylight.NIF

  @native_path Application.app_dir(:skylight, "priv") |> Path.join("skylight_x86_64-darwin")
  @skylightd_path Path.join(@native_path, "skylightd")
  @libskylight_path Path.join(@native_path, "libskylight.dylib")

  @bare_agent_env [
    "SKYLIGHT_AUTHENTICATION", TestHelpers.auth_token(),
    "SKYLIGHT_VERSION", "0.8.1",
    "SKYLIGHT_LAZY_START", "false",
    "SKYLIGHT_DAEMON_EXEC_PATH", @skylightd_path,
    "SKYLIGHT_DAEMON_LIB_PATH", Path.dirname(@libskylight_path),
    "SKYLIGHT_AUTH_URL", "https://auth.skylight.io/agent",
    "SKYLIGHT_VALIDATE_AUTHENTICATION", "false",
    "SKYLIGHT_LOG_FILE", "-",
    "SKYLIGHT_LOG_LEVEL", "DEBUG",
    "SKYLIGHT_DAEMON_READ_TIMEOUT", "10",
  ]

  setup_all do
    :ok = NIF.load_libskylight(@libskylight_path)
  end

  test "hrtime/0" do
    hrtime = NIF.hrtime()
    assert is_integer(hrtime)
    assert hrtime > 1_000_000_000_000
  end

  test "instrumenter_new/1, instrumenter_start/1, and instrumenter_stop/1" do
    instrumenter = NIF.instrumenter_new(@bare_agent_env)
    assert resource?(instrumenter)

    assert NIF.instrumenter_start(instrumenter) == :ok
    assert NIF.instrumenter_stop(instrumenter) == :ok
  end

  test "lex_sql/1" do
    sql = "SELECT * FROM my_table WHERE my_field = 'my value'";
    assert NIF.lex_sql(sql) == "SELECT * FROM my_table WHERE my_field = ?";
  end

  # For now, let's identify a resource as just an empty binary.
  defp resource?(""), do: true
  defp resource?(_), do: false
end
