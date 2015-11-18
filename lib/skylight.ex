defmodule Skylight do
  use Application

  @type resource :: binary

  def start(_type, _args) do
    import Supervisor.Spec

    load_libskylight!()

    children = [
      worker(Skylight.InstrumenterAgent, []),
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def stop(_state) do
    inst = Skylight.InstrumenterAgent.get()
    :ok = Skylight.Instrumenter.stop(inst)
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
