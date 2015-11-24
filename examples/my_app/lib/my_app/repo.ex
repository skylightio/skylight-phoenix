defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app
end

defmodule MyApp.Skylight.Repo do
  use Skylight.Ecto.Repo, proxy_to: MyApp.Repo
end
