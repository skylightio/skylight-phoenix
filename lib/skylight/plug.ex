if Code.ensure_compiled?(Plug) do
  defmodule Skylight.Plug do
    @moduledoc """
    A plug to instrument the current request.

    This plug is meant to be used as the first plug in the plug pipeline of your
    application. It will instrument each request that goes through the pipeline,
    measuring the time it takes for the request to be handled and for the response
    to be sent.

    Read the documentation for the `Skylight` module for more information about
    Skylight and its configuration.

    ## Examples

    For accurate results, this plug should be placed first in the plug pipeline of
    your application.

    defmodule MyApp.Endpoint do
    plug Skylight.Plug
    # all other plugs
    end

    """

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

      Trace.unstore()

      conn
    end

    defp get_route(conn) do
      controller = conn.private[:phoenix_controller]
      action = conn.private[:phoenix_action]
      controller && action && (inspect(controller) <> "#" <> to_string(action))
    end
  end
end
