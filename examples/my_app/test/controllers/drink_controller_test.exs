defmodule MyApp.DrinkControllerTest do
  use MyApp.ConnCase

  alias MyApp.Drink
  @valid_attrs %{brand: "some content", price: "120.5"}
  @invalid_attrs %{}

  setup do
    conn = conn()
    {:ok, conn: conn}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, drink_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing drinks"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, drink_path(conn, :new)
    assert html_response(conn, 200) =~ "New drink"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, drink_path(conn, :create), drink: @valid_attrs
    assert redirected_to(conn) == drink_path(conn, :index)
    assert Repo.get_by(Drink, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, drink_path(conn, :create), drink: @invalid_attrs
    assert html_response(conn, 200) =~ "New drink"
  end

  test "shows chosen resource", %{conn: conn} do
    drink = Repo.insert! %Drink{}
    conn = get conn, drink_path(conn, :show, drink)
    assert html_response(conn, 200) =~ "Show drink"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      get conn, drink_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    drink = Repo.insert! %Drink{}
    conn = get conn, drink_path(conn, :edit, drink)
    assert html_response(conn, 200) =~ "Edit drink"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    drink = Repo.insert! %Drink{}
    conn = put conn, drink_path(conn, :update, drink), drink: @valid_attrs
    assert redirected_to(conn) == drink_path(conn, :show, drink)
    assert Repo.get_by(Drink, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    drink = Repo.insert! %Drink{}
    conn = put conn, drink_path(conn, :update, drink), drink: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit drink"
  end

  test "deletes chosen resource", %{conn: conn} do
    drink = Repo.insert! %Drink{}
    conn = delete conn, drink_path(conn, :delete, drink)
    assert redirected_to(conn) == drink_path(conn, :index)
    refute Repo.get(Drink, drink.id)
  end
end
