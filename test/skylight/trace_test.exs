defmodule Skylight.TraceTest do
  use ExUnit.Case, async: true

  alias Skylight.Trace

  test "implementation of Inspect.inspect/2" do
    assert inspect(%Trace{}) == "#Skylight.Trace<a-trace>"
  end
end
