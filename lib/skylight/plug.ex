defmodule Skylight.Plug do
  @behaviour Plug

  require Logger

  alias Skylight.Trace
  alias Skylight.Instrumenter
  alias Skylight.InstrumenterAgent

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

    conn
    |> put_new_trace_handle(:whole_req, whole_req_handle)
    |> register_before_send(&before_send/1)
  end

  defp before_send(conn) do
    {trace, handle} = get_trace_and_handle(conn, :whole_req)

    if endpoint = get_route(conn) do
      :ok = Trace.set_endpoint(trace, endpoint)
    end

    # Clean up the connection so that the trace in the connection can't be used
    # after it's been submitted (because it's been freed by then).
    conn = clean_up_conn(conn)

    :ok = Trace.mark_span_as_done(trace, handle)
    :ok = Instrumenter.submit_trace(inst(), trace)
    Process.delete(:skylight_trace)

    # Oh god, state is hard. Here, we can't inspect the trace (or really, use it
    # in any way) because submitting it made Rust free it. :(

    conn
  end

  defp inst() do
    InstrumenterAgent.get()
  end

  defp clean_up_conn(conn) do
    put_private(conn, :skylight_trace_handles, %{})
  end

  defp put_new_trace_handle(conn, name, handle) do
    handles = conn.private[:skylight_trace_handles] || %{}
    handles = Map.put(handles, name, handle)
    put_private(conn, :skylight_trace_handles, handles)
  end

  defp get_trace_and_handle(conn, name) do
    {Trace.fetch(), conn.private[:skylight_trace_handles][name]}
  end

  defp get_route(conn) do
    controller = conn.private[:phoenix_controller]
    action = conn.private[:phoenix_action]
    controller && action && (inspect(controller) <> "#" <> to_string(action))
  end
end
