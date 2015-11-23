defmodule Skylight.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule MyApp do
    use Plug.Router

    plug Skylight.Plug
    plug :match
    plug :dispatch

    match _ do
      send_resp(conn, 200, "")
    end
  end

  test "basic callback registration" do
    conn = conn(:get, "/foo") |> MyApp.call([])
    assert Map.has_key?(conn.private, :skylight_trace)
    assert Map.has_key?(conn.private, :skylight_trace_handles)
  end
end
