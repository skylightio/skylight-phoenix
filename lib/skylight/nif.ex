defmodule Skylight.NIF do
  @moduledoc false

  @on_load :load_nifs

  # Loads the .so file that contains the NIFs.
  def load_nifs() do
    :erlang.load_nif(nif_path(), 0)
  end

  # Add default clauses for all NIFs. The default clauses just raise an
  # exception.
  nifs = [
    {:load_libskylight, 1},
    {:hrtime, 0},
    {:instrumenter_new, 1},
    {:instrumenter_start, 1},
    {:instrumenter_stop, 1},
    {:trace_new, 3},
    {:trace_start, 1},
    {:trace_endpoint, 1},
    {:trace_set_endpoint, 2},
    {:trace_uuid, 1},
    {:trace_set_uuid, 2},
    {:lex_sql, 1},
  ]

  for {name, arity} <- nifs do
    args = List.duplicate(quote(do: _), arity)

    def unquote(name)(unquote_splicing(args)) do
      raise "NIF #{unquote(name)}/#{unquote(arity)} not implemented"
    end
  end

  defp nif_path() do
    Application.app_dir(:skylight, "priv")
    |> Path.join("skylight_x86_64-darwin")
    |> Path.join("skylight_nif")
    |> String.to_char_list
  end
end
