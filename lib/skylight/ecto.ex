if :code.is_loaded(Ecto) do
  defmodule Skylight.Ecto do

    def register_log_entry(%Ecto.LogEntry{} = _entry) do
      :ok
    end
  end
end
