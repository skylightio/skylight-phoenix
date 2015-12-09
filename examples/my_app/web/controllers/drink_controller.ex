defmodule MyApp.DrinkController do
  use MyApp.Web, :controller

  alias MyApp.Drink

  plug :scrub_params, "drink" when action in [:create, :update]

  def index(conn, _params) do
    drinks = Repo.all(Drink)
    render(conn, "index.html", drinks: drinks)
  end

  def new(conn, _params) do
    changeset = Drink.changeset(%Drink{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"drink" => drink_params}) do
    changeset = Drink.changeset(%Drink{}, drink_params)

    case Repo.insert(changeset) do
      {:ok, _drink} ->
        conn
        |> put_flash(:info, "Drink created successfully.")
        |> redirect(to: drink_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    drink = Repo.get!(Drink, id)
    render(conn, "show.html", drink: drink)
  end

  def edit(conn, %{"id" => id}) do
    drink = Repo.get!(Drink, id)
    changeset = Drink.changeset(drink)
    render(conn, "edit.html", drink: drink, changeset: changeset)
  end

  def update(conn, %{"id" => id, "drink" => drink_params}) do
    drink = Repo.get!(Drink, id)
    changeset = Drink.changeset(drink, drink_params)

    case Repo.update(changeset) do
      {:ok, drink} ->
        conn
        |> put_flash(:info, "Drink updated successfully.")
        |> redirect(to: drink_path(conn, :show, drink))
      {:error, changeset} ->
        render(conn, "edit.html", drink: drink, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    drink = Repo.get!(Drink, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(drink)

    conn
    |> put_flash(:info, "Drink deleted successfully.")
    |> redirect(to: drink_path(conn, :index))
  end
end
