defmodule Skylight.Plug do
  @behaviour Plug

  require Logger

  alias Skylight.Trace
  alias Skylight.Instrumenter
  alias Skylight.Store

  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    trace = Trace.new("default")
    :ok = Trace.store(trace)

    whole_req_handle = Trace.instrument(trace, "app.whole_req")
    :ok = Trace.set_span_title(trace, whole_req_handle, "app.whole_req")

    Logger.debug "Created a new trace for request at \"#{conn.request_path}\": #{inspect trace}"

    register_before_send(conn, &before_send(&1, whole_req_handle))
  end

  defp before_send(conn, whole_req_handle) do
    trace = Trace.fetch()

    if endpoint = get_route(conn) do
      :ok = Trace.set_endpoint(trace, endpoint)
    end

    :ok = Trace.mark_span_as_done(trace, whole_req_handle)
    :ok = Instrumenter.submit_trace(Store.get_instrumenter(), trace)
    Process.delete(:skylight_trace)

    conn
  end

  defp get_route(conn) do
    controller = conn.private[:phoenix_controller]
    action = conn.private[:phoenix_action]
    controller && action && (inspect(controller) <> "#" <> to_string(action))
  end
end
