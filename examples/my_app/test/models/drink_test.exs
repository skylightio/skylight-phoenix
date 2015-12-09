defmodule MyApp.DrinkTest do
  use MyApp.ModelCase

  alias MyApp.Drink

  @valid_attrs %{brand: "some content", price: "120.5"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Drink.changeset(%Drink{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Drink.changeset(%Drink{}, @invalid_attrs)
    refute changeset.valid?
  end
end
