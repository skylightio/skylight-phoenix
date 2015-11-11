defmodule Skylight.TraceTest do
  use ExUnit.Case, async: true

  alias Skylight.Trace

  @native_path File.cwd!() |> Path.join("c_src/skylight_x86_64-darwin")
  @skylightd_path Path.join(@native_path, "skylightd")
  @libskylight_path Path.join(@native_path, "libskylight.dylib")

  setup_all do
    {:ok, _} = Skylight.NIF.load_libskylight(@libskylight_path)
    :ok
  end

  test "implementation of Inspect.inspect/2" do
    assert inspect(%Trace{}) == "#Skylight.Trace<a-trace>"
  end

  test "new/1" do
    assert %Trace{} = trace = Trace.new("MyController#my_endpoint")
    refute is_nil(trace.resource)
  end

  test "get_started_at/1" do
    started_at = Trace.get_started_at(Trace.new("foo"))
    assert is_integer(started_at)
    assert started_at > 1_000_000_000_000
  end

  test "get_endpoint/1 and put_endpoint/2" do
    trace = Trace.new("my_trace")
    assert Trace.get_endpoint(trace) == "my_trace"
    assert :ok = Trace.put_endpoint(trace, "my_new_trace")
    assert Trace.get_endpoint(trace) == "my_new_trace"
  end

  test "get_uuid/1 and put_uuid/2" do
    trace = Trace.new("my_trace")
    assert byte_size(Trace.get_uuid(trace)) > 0
    new_uuid = UUID.uuid4()
    assert :ok = Trace.put_uuid(trace, new_uuid)
    assert Trace.get_uuid(trace) == new_uuid
  end
end
