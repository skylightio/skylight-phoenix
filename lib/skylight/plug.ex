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
    trace = Trace.new("fake#endpoint")
    whole_req_handle = Trace.instrument(trace, "app.whole_req")

    Logger.debug "Created a new trace for request at \"#{conn.request_path}\": #{inspect trace}"

    conn
    |> put_private(:skylight_trace, trace)
    |> put_new_trace_handle(:whole_req, whole_req_handle)
    |> register_before_send(&before_send/1)
  end

  def controller_hook(conn, _opts) do
    {trace, handle} = get_trace_and_handle(conn, :whole_req)
    route = get_route(conn)
    :ok = Trace.put_endpoint(trace, get_route(conn))
    :ok = Trace.set_span_title(trace, handle, route)
    :ok = Trace.set_span_desc(trace, handle, route)

    Logger.debug "Changed the endpoint of the current trace in the controller: #{inspect trace}"

    conn
  end

  defp before_send(conn) do
    {trace, handle} = get_trace_and_handle(conn, :whole_req)

    # Clean up the connection.
    conn =
      conn
      |> put_private(:skylight_trace, nil)
      |> put_private(:skylight_trace_handles, %{})

    :ok = Trace.mark_span_as_done(trace, handle)
    :ok = Instrumenter.submit_trace(inst(), trace)

    # Oh god, state is hard. Here, we can't inspect the trace (or really, use it
    # in any way) because submitting it made Rust free it. :(

    conn
  end

  defp inst() do
    InstrumenterAgent.get()
  end

  defp put_new_trace_handle(conn, name, handle) do
    handles = conn.private[:skylight_trace_handles] || %{}
    handles = Map.put(handles, name, handle)
    put_private(conn, :skylight_trace_handles, handles)
  end

  defp get_trace_and_handle(conn, name) do
    {conn.private[:skylight_trace], conn.private[:skylight_trace_handles][name]}
  end

  defp get_route(conn) do
    controller = conn.private[:phoenix_controller]
    action = conn.private[:phoenix_action]
    inspect(controller) <> "#" <> to_string(action)
  end
end
