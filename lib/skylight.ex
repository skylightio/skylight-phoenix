defmodule Skylight do
  use Application

  @type resource :: binary

  def start(_type, _args) do
    load_libskylight!()

    # Empty supervisor, just because you have to return `{:ok, pid}` here.
    Supervisor.start_link([], strategy: :one_for_one)
  end

  defp load_libskylight!() do
    path = Application.app_dir(:skylight, "priv") |> Path.join("libskylight.dylib")

    case Skylight.NIF.load_libskylight(path) do
      {:ok, _} -> :ok
      :error   -> raise "couldn't load libskylight from #{path}"
    end
  end
end
