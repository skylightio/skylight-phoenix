if Code.ensure_loaded?(Ecto) do
  defmodule Skylight.Ecto do
    alias Skylight.Trace

    @doc """
    Instruments a function using the given `queryable` to find the title.

    This function instruments the running of `fun`, using `repo`, `kind`, and
    `queryable` to generate the SQL query (lexed) which is used as the title for
    the new span.
    """
    @spec instrument(Ecto.Repo.t, atom, Ecto.Queryable.t, (() -> term)) :: :ok
    def instrument(repo, kind, queryable, fun) do
      trace = Trace.fetch()
      handle = nil

      if trace do
        query = query_to_string(repo, kind, queryable)
        handle = Trace.instrument(trace, "ecto.query")
        :ok = Trace.set_span_title(trace, handle, query)
        :ok = Trace.set_span_desc(trace, handle, query)
      end

      try do
        fun.()
      after
        if trace do
          :ok = Trace.mark_span_as_done(trace, handle)
        end
      end
    end

    defp query_to_string(repo, kind, queryable) when kind in ~w(all update_all delete_all)a do
      {query, _} = Ecto.Adapters.SQL.to_sql(kind, repo, queryable)
      query
    end

    defp query_to_string(_repo, _kind, queryable) do
      inspect(queryable)
    end
  end
end
