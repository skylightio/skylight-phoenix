defmodule MyApp.PageController do
  use MyApp.Web, :controller

  alias MyApp.User

  def index(conn, _params) do
    user = Repo.one!((from u in User, where: u.email == "foo@bar.com"))
    render conn, "index.html", user_email: user.email
  end

  def bare(conn, _params) do
    html conn, ""
  end
end
