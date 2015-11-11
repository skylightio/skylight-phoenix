defmodule Skylight.Instrumenter do
  @moduledoc """
  A Skylight instrumenter object.
  """

  @type t :: %__MODULE__{
    resource: Skylight.resource,
  }

  defstruct [:resource]

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(inst, opts) do
      concat ["#Skylight.Instrumenter<", "an-instrumenter", ">"]
    end
  end
end
