defmodule MyApp.PageController do
  use MyApp.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def bare(conn, _params) do
    html conn, ""
  end
end
