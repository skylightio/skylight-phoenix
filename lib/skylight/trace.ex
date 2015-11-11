defmodule Skylight.Trace do
  @moduledoc """
  A Skylight trace object.
  """

  @type t :: %__MODULE__{
    resource: Skylight.resource,
  }

  defstruct [:resource]

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(_trace, _opts) do
      concat ["#Skylight.Trace<", "a-trace", ">"]
    end
  end
end
