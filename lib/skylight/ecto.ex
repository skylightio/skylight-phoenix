if Code.ensure_compiled?(Ecto) do
  defmodule Skylight.Ecto do
    @moduledoc """
    TODO
    """

    alias Skylight.Trace

    require Logger

    @doc """
    TODO
    """
    @spec instrument(Ecto.Repo.t, (() -> term)) :: :ok
    def instrument(repo, fun) do
      trace = Trace.fetch()

      handle = if trace do
        Trace.instrument(trace, "db.ecto.query")
      else
        Logger.debug "No trace found in the current process"
        nil
      end

      try do
        fun.()
      after
        if trace && handle do
          log_entry = Process.get(:ecto_log_entry)
          if log_entry do
            :ok = Trace.set_span_sql(trace, handle, log_entry.query, sql_flavor(repo))
            Process.delete(:ecto_log_entry)
          end
          :ok = Trace.mark_span_as_done(trace, handle)
        else
          :ok
        end
      end
    end

    defp sql_flavor(repo) do
      case repo.__adapter__ do
        Ecto.Adapters.MySQL    -> :mysql
        Ecto.Adapters.Postgres -> :postgres
        _                      -> :generic
      end
    end
  end
end
