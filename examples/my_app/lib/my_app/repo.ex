defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app
  use Skylight.Ecto.Repo
end
