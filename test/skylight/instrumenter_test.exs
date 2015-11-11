defmodule Skylight.InstrumenterTest do
  use ExUnit.Case, async: true

  alias Skylight.Instrumenter

  test "implementation of Inspect.inspect/2" do
    assert inspect(%Instrumenter{}) == "#Skylight.Instrumenter<an-instrumenter>"
  end
end
