# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     MyApp.Repo.insert!(%SomeModel{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias MyApp.Skylight.Repo
alias MyApp.User

import Ecto.Query

email = "foo@bar.com"
query = from u in User, where: u.email == ^email

unless Repo.one(query) do
  Repo.insert!(%User{email: email})
end
