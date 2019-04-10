defmodule Skylight.NIFTest do
  use ExUnit.Case
  alias Skylight.TestHelpers

  import Skylight.NIF

  @priv Application.app_dir(:skylight, "priv")

  @bare_agent_env [
    "SKYLIGHT_AUTHENTICATION",
    TestHelpers.auth_token(),
    "SKYLIGHT_VERSION",
    "0.8.1",
    "SKYLIGHT_LAZY_START",
    "false",
    "SKYLIGHT_DAEMON_EXEC_PATH",
    Path.join(@priv, "skylightd"),
    "SKYLIGHT_DAEMON_LIB_PATH",
    @priv,
    "SKYLIGHT_SOCKDIR_PATH",
    "/tmp",
    "SKYLIGHT_AUTH_URL",
    "https://auth.skylight.io/agent",
    "SKYLIGHT_VALIDATE_AUTHENTICATION",
    "false"
  ]

  setup_all do
    instrumenter = instrumenter_new(@bare_agent_env)
    :ok = instrumenter_start(instrumenter)

    on_exit(fn ->
      :ok = instrumenter_stop(instrumenter)
    end)

    {:ok, %{inst: instrumenter}}
  end

  test "hrtime/0" do
    hrtime = hrtime()
    assert is_integer(hrtime)
    assert hrtime > 1_000_000_000_000
  end

  test "instrumenter_track_desc/3", %{inst: instrumenter} do
    assert instrumenter_track_desc(instrumenter, "my_endpoint", "my_desc")
  end

  test "trace_new/3" do
    trace = trace_new(hrtime(), UUID.uuid4(), "MyController#my_route")
    assert is_reference(trace)
  end

  test "trace_start/1" do
    started_at = hrtime()
    trace = trace_new(started_at, UUID.uuid4(), "MyController#my_route")
    assert trace_start(trace) == started_at
  end

  test "trace_endpoint/1 and trace_set_endpoint/2" do
    endpoint = "MyController#my_trace_endpoint_to_check"
    new_endpoint = "MyController#new_endpoint"

    trace = trace_new(hrtime(), UUID.uuid4(), endpoint)

    assert trace_endpoint(trace) == endpoint
    assert :ok = trace_set_endpoint(trace, new_endpoint)
    assert trace_endpoint(trace) == new_endpoint
  end

  test "trace_uuid/1 and trace_set_uuid/2" do
    uuid = UUID.uuid4()
    new_uuid = UUID.uuid4()

    trace = trace_new(hrtime(), uuid, "MyController#my_endpoint")

    assert trace_uuid(trace) == uuid
    assert :ok = trace_set_uuid(trace, new_uuid)
    assert trace_uuid(trace) == new_uuid
  end

  test "instrumenter_submit_trace/2", %{inst: instrumenter} do
    trace = trace_new(100, UUID.uuid4(), "MyController#my_endpoint")
    assert :ok = instrumenter_submit_trace(instrumenter, trace)
  end

  test "trace_instrument/3, trace_span_set_(title|desc)/3, trace_span_done/3" do
    trace = trace_new(hrtime(), UUID.uuid4(), "my_endpoint")

    handle = trace_instrument(trace, hrtime(), "my_category")
    assert is_integer(handle)

    assert :ok = trace_span_set_title(trace, handle, "my title")
    assert :ok = trace_span_set_desc(trace, handle, "my desc")

    assert :ok = trace_span_done(trace, handle, hrtime())
  end

  test "lex_sql/1" do
    sql = "SELECT * FROM my_table WHERE my_field = 'my value'"
    assert lex_sql(sql) == "SELECT * FROM my_table WHERE my_field = ?"
  end

  # For now, let's identify a resource as just an empty binary.
  defp resource?(""), do: true
  defp resource?(_), do: false
end
