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
    time = conn.private[:skylight_resp_time]
    assert is_integer(time) and time > 0
  end
end
