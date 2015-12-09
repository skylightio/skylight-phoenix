defmodule MyApp.Drink do
  use MyApp.Web, :model

  schema "drinks" do
    field :brand, :string
    field :price, :float

    timestamps
  end

  @required_fields ~w(brand price)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
