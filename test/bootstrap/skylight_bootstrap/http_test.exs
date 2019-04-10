defmodule SkylightBootstrap.HTTPTest do
  use ExUnit.Case

  alias SkylightBootstrap.HTTP

  # As random as possible!
  @cowboy_port 49483

  # defmodule CowboyHandler do
  #   def init(_type, req, _opts) do
  #     {:ok, req, :nostate}
  #   end

  #   def handle(req, :nostate) do
  #     {:ok, reply} = :cowboy_req.reply(200, [{"content-type", "text/plain"}], "Hello", req)
  #     {:ok, reply, :nostate}
  #   end

  #   def terminate(_, _, _), do: :ok
  # end

  setup_all do
    Application.ensure_all_started(:bypass)

    bypass = Bypass.open(port: @cowboy_port)

    Bypass.stub(bypass, "GET", "/", fn conn ->
      Plug.Conn.resp(conn, 200, "Hello")
    end)

    Bypass.stub(bypass, "GET", "/nonexistent", fn conn ->
      Plug.Conn.resp(conn, 404, "Not Found")
    end)
  end

  test "get/1 with a known URL" do
    assert HTTP.get(url("/")) == {:ok, "Hello"}
  end

  test "get/1 with a 404 url" do
    assert HTTP.get(url("/nonexistent")) == {:error, {:http_error, 404, 'Not Found'}}
  end

  defp url(where) do
    "http://localhost:#{@cowboy_port}#{where}"
  end
end
