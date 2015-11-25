defmodule Skylight.TraceTest do
  use ExUnit.Case, async: true

  alias Skylight.Trace

  test "implementation of Inspect.inspect/2" do
    assert inspect(Trace.new("my_trace"))
           =~ ~r/#Skylight\.Trace<uuid: .{36}, endpoint: "my_trace">/
  end

  test "new/1" do
    assert %Trace{} = trace = Trace.new("MyController#my_endpoint")
    refute is_nil(trace.resource)
  end

  test "get_started_at/1" do
    started_at = Trace.get_started_at(Trace.new("foo"))
    assert is_integer(started_at)
  end

  test "get_endpoint/1 and set_endpoint/2" do
    trace = Trace.new("my_trace")
    assert Trace.get_endpoint(trace) == "my_trace"
    assert :ok = Trace.set_endpoint(trace, "my_new_trace")
    assert Trace.get_endpoint(trace) == "my_new_trace"
  end

  test "get_uuid/1 and set_uuid/2" do
    trace = Trace.new("my_trace")
    assert byte_size(Trace.get_uuid(trace)) > 0
    new_uuid = UUID.uuid4()
    assert :ok = Trace.set_uuid(trace, new_uuid)
    assert Trace.get_uuid(trace) == new_uuid
  end

  test "instrument/2, set_span_title/3, set_span_desc/2 and mark_span_as_done/2" do
    trace = Trace.new("my_trace")
    handle = Trace.instrument(trace, "my category")
    assert is_integer(handle)

    assert :ok = Trace.set_span_title(trace, handle, "my title")
    assert :ok = Trace.set_span_desc(trace, handle, "my desc")
    assert :ok = Trace.mark_span_as_done(trace, handle)
  end
end
