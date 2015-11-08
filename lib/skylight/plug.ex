defmodule Skylight.Plug do
  @behaviour Plug

  require Logger

  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    req_start_timestamp = :os.timestamp()
    register_before_send(conn, &before_send(&1, req_start_timestamp))
  end

  defp before_send(conn, req_start_timestamp) do
    diff = :timer.now_diff(:os.timestamp(), req_start_timestamp)
    put_private(conn, :skylight_resp_time, diff)
  end
end
