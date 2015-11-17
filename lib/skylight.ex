defmodule Skylight do
  use Application

  @type resource :: binary

  def start(_type, _args) do
    load_libskylight!()

    # Empty supervisor, just because you have to return `{:ok, pid}` here.
    Supervisor.start_link([], strategy: :one_for_one)
  end

  defp load_libskylight!() do
    path = Application.app_dir(:skylight, "priv") |> Path.join("libskylight.#{so_ext()}")

    case Skylight.NIF.load_libskylight(path) do
      {:ok, _} -> :ok
      :error   -> raise "couldn't load libskylight from #{path}"
    end
  end

  defp so_ext() do
    # TODO include Windows in this (with a .dll extension).
    case :os.type() do
      {:unix, :darwin} -> "dylib"
      {:unix, _}       -> "so"
    end
  end
end
