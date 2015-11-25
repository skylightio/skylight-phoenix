defmodule Skylight.NIF.Macros do
  @moduledoc false

  @doc """
  Defines a failing clause for the given function.

  The utility of this macro (instead of just using `{:my_fun, arity}`) is that
  it allows for much better documentation and specs because every `defnif` can
  be preceded by @docs and @specs.

  ## Examples

      @doc "Does stuff"
      @spec my_nif(term, term) :: term
      defnif my_nif(arg1, arg2)

  """
  defmacro defnif(fun_signature) do
    {fun, args} = Macro.decompose_call(fun_signature)
    args = underscorize_args(args)

    quote do
      def unquote(fun)(unquote_splicing(args)) do
        raise "NIF #{unquote(fun)}/#{unquote(length(args))} not implemented"
      end
    end
  end

  defp underscorize_args(args) do
    for {name, meta, nil} <- args do
      {String.to_atom("_" <> Atom.to_string(name)), meta, nil}
    end
  end
end

defmodule Skylight.NIF do
  @moduledoc false

  import Skylight.NIF.Macros

  @on_load :load_nifs

  defnif load_libskylight(path)
  defnif hrtime()
  defnif instrumenter_new(env)
  defnif instrumenter_start(inst)
  defnif instrumenter_stop(inst)
  defnif instrumenter_submit_trace(inst, trace)
  defnif instrumenter_track_desc(inst, endpoint, desc)
  defnif trace_new(start, uuid, endpoint)
  defnif trace_start(trace)
  defnif trace_endpoint(trace)
  defnif trace_set_endpoint(trace, endpoint)
  defnif trace_uuid(trace)
  defnif trace_set_uuid(trace, uuid)
  defnif trace_instrument(trace, time, category)
  defnif trace_span_set_title(trace, handle, title)
  defnif trace_span_set_desc(trace, handle, desc)
  defnif trace_span_done(trace, handle, time)
  defnif trace_span_set_sql(trace, handle, sql, flavor)
  defnif lex_sql(sql)

  # Loads the .so file that contains the NIFs.
  def load_nifs() do
    :erlang.load_nif(nif_path(), 0)
  end

  defp nif_path() do
    Application.app_dir(:skylight, "priv")
    |> Path.join("skylight_nif")
    |> String.to_char_list
  end
end
