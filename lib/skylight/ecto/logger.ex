defmodule Skylight.Ecto.Logger do

  def log(entry) do
    Process.put(:ecto_log_entry, entry)
    entry
  end

end
