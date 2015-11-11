defmodule Skylight.InstrumenterTest do
  use ExUnit.Case, async: true

  alias Skylight.TestHelpers
  alias Skylight.Instrumenter

  @native_path File.cwd!() |> Path.join("c_src/skylight_x86_64-darwin")
  @skylightd_path Path.join(@native_path, "skylightd")
  @libskylight_path Path.join(@native_path, "libskylight.dylib")

  @bare_agent_env %{
    "SKYLIGHT_AUTHENTICATION" => TestHelpers.auth_token(),
    "SKYLIGHT_VERSION" => "0.8.1",
    "SKYLIGHT_LAZY_START" => "false",
    "SKYLIGHT_DAEMON_EXEC_PATH" => @skylightd_path,
    "SKYLIGHT_DAEMON_LIB_PATH" => Path.dirname(@libskylight_path),
    "SKYLIGHT_AUTH_URL" => "https://auth.skylight.io/agent",
    "SKYLIGHT_VALIDATE_AUTHENTICATION" => "false",
    "SKYLIGHT_DAEMON_READ_TIMEOUT" => "5s",
    }

  setup_all do
    {:ok, _} = Skylight.NIF.load_libskylight(@libskylight_path)
    :ok
  end

  test "implementation of Inspect.inspect/2" do
    assert inspect(%Instrumenter{}) == "#Skylight.Instrumenter<an-instrumenter>"
  end

  test "new/1, start/1 and stop/1" do
    assert %Instrumenter{} = inst = Instrumenter.new(@bare_agent_env)
    refute is_nil(inst.resource)

    assert :ok = Instrumenter.start(inst)
    assert :ok = Instrumenter.stop(inst)
  end
end
