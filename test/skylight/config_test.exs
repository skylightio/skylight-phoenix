defmodule Skylight.ConfigTest do
  use ExUnit.Case

  alias Skylight.Config

  test "read/0" do
    Application.put_env(:skylight, :foo, {:system, "SKYLIGHT_TESTS_FOO"})
    Application.put_env(:skylight, :nil_env, {:system, "SKYLIGHT_TEST_NONEXISTENT"})
    Application.put_env(:skylight, :bar_with_underscore, true)

    System.put_env("SKYLIGHT_TESTS_FOO", "yay!")

    config = Config.read()

    assert config["SKYLIGHT_FOO"] == "yay!"
    assert config["SKYLIGHT_BAR_WITH_UNDERSCORE"] == "true"
    refute Map.has_key?(config, "SKYLIGHT_NIL_ENV")
  end
end
