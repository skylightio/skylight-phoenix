defmodule MyApp.Repo.Migrations.CreateDrink do
  use Ecto.Migration

  def change do
    create table(:drinks) do
      add :brand, :string
      add :price, :float

      timestamps
    end

  end
end
