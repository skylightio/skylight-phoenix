defmodule Skylight.InstrumenterAgent do
  alias Skylight.Instrumenter

  def start_link() do
    Agent.start_link(&create_instrumenter/0, name: __MODULE__)
  end

  def get(timeout \\ 5000) do
    Agent.get(__MODULE__, &(&1), timeout)
  end

  @priv Application.app_dir(:skylight, "priv")
  @instrumenter_env %{
    "SKYLIGHT_AUTHENTICATION" => (System.get_env("DIREWOLF_PHOENIX_TOKEN") || raise "missing token"),
    "SKYLIGHT_VERSION" => "0.8.1",
    "SKYLIGHT_LAZY_START" => "false",
    "SKYLIGHT_DAEMON_EXEC_PATH" => Path.join(@priv, "skylightd"),
    "SKYLIGHT_DAEMON_LIB_PATH" => @priv,
    "SKYLIGHT_SOCKDIR_PATH" => "/tmp",
    "SKYLIGHT_AUTH_URL" => "https://auth.skylight.io/agent",
    "SKYLIGHT_VALIDATE_AUTHENTICATION" => "false",
  }

  defp create_instrumenter() do
    inst = Instrumenter.new(@instrumenter_env)
    :ok = Instrumenter.start(inst)
    inst
  end
end
