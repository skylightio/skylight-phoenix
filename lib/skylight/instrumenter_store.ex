defmodule Skylight.InstrumenterStore do
  @moduledoc """
  TODO
  """

  @table_name :skylight

  alias Skylight.Instrumenter

  @doc """
  """
  @spec start_link() :: GenServer.on_start
  def start_link() do
    Agent.start_link(&create_ets_table/0)
  end

  @doc """
  """
  @spec get(timeout) :: Instrumenter.t
  def get(timeout \\ 5000) do
    case :ets.lookup(@table_name, :instrumenter) do
      [] ->
        raise "instrumenter not found in the ETS table"
      [{:instrumenter, instrumenter}] ->
        instrumenter
    end
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

  defp create_ets_table do
    :ets.new(@table_name, [:protected, :named_table, :set])
    :ets.insert(@table_name, {:instrumenter, create_and_start_instrumenter()})
  end

  defp create_and_start_instrumenter do
    inst = Instrumenter.new(@instrumenter_env)
    :ok = Instrumenter.start(inst)
    inst
  end
end
