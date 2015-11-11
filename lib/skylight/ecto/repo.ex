defmodule Skylight.Ecto.Repo do
  defmacro __using__(_opts) do
    quote do
      def log(log_entry) do
        :ok = Skylight.Ecto.register_log_entry(log_entry)
        super(log_entry)
      end
    end
  end
end
