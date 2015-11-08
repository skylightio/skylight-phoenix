defmodule Skylight.NIFTest do
  use ExUnit.Case
  alias Skylight.TestHelpers

  alias Skylight.NIF

  @native_path File.cwd!() |> Path.join("c_src/skylight_x86_64-darwin")
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
    "SKYLIGHT_DAEMON_READ_TIMEOUT", "5s",
  ]

  setup_all do
    :crypto.rand_bytes(10)
    {:ok, :loaded} = NIF.load_libskylight(@libskylight_path)
    :ok
  end

  setup do
    instrumenter = NIF.instrumenter_new(@bare_agent_env)
    :ok = NIF.instrumenter_start(instrumenter)

    {:ok, %{instr: instrumenter}}
  end

  test "hrtime/0" do
    hrtime = NIF.hrtime()
    assert is_integer(hrtime)
    assert hrtime > 1_000_000_000_000
  end

  test "instrumenter_new/1, instrumenter_start/1, and instrumenter_stop/1" do
    instrumenter = NIF.instrumenter_new(@bare_agent_env)
    assert resource?(instrumenter, :instrumenter)

    assert NIF.instrumenter_start(instrumenter) ==:ok
    assert NIF.instrumenter_stop(instrumenter) == :ok
  end

  test "trace_new/3" do
    trace = NIF.trace_new(100, UUID.uuid4(), "MyController#my_route")
    assert resource?(trace, :trace)
  end

  test "trace_start/1" do
    trace = NIF.trace_new(100, UUID.uuid4(), "MyController#my_route")
    assert is_integer(NIF.trace_start(trace))
  end

  test "trace_endpoint/1 and trace_set_endpoint/2" do
    endpoint = "MyController#my_trace_endpoint_to_check"
    new_endpoint = "MyController#new_endpoint"
    trace = NIF.trace_new(100, UUID.uuid4(), endpoint)
    assert NIF.trace_endpoint(trace) == endpoint
    assert :ok = NIF.trace_set_endpoint(trace, new_endpoint)
    assert NIF.trace_endpoint(trace) == new_endpoint
  end

  test "trace_uuid/1 and trace_set_uuid/2" do
    uuid = UUID.uuid4()
    new_uuid = UUID.uuid4()

    trace = NIF.trace_new(100, uuid, "MyController#my_endpoint")

    assert NIF.trace_uuid(trace) == uuid
    assert :ok = NIF.trace_set_uuid(trace, new_uuid)
    assert NIF.trace_uuid(trace) == new_uuid
  end

  test "lex_sql/1" do
    sql = "SELECT * FROM my_table WHERE my_field = 'my value'";
    assert NIF.lex_sql(sql) == "SELECT * FROM my_table WHERE my_field = ?";
  end

  # For now, let's identify a resource as just an empty binary.
  defp resource?("", _type), do: true
  defp resource?(_, _type), do: false
end
