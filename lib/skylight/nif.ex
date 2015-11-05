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
    {:lex_sql, 1},
  ]

  for {name, arity} <- nifs do
    args = List.duplicate(quote(do: _), arity)

    def unquote(name)(unquote_splicing(args)) do
      raise "NIF #{unquote(name)}/#{unquote(arity)} not implemented"
    end
  end

  defp nif_path() do
    __ENV__.file
    |> Path.join("../../../native/skylight_x86_64-darwin/skylight_nif")
    |> Path.expand
    |> String.to_char_list
  end
end
