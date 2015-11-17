defmodule Skylight.Instrumenter do
  @moduledoc """
  A Skylight instrumenter object.
  """

  @type t :: %__MODULE__{
    resource: Skylight.resource,
  }

  alias __MODULE__
  alias Skylight.NIF
  alias Skylight.Trace

  defstruct [:resource]

  @spec new(%{}) :: t
  def new(env) when is_map(env) do
    resource =
      env
      |> Enum.flat_map(&Tuple.to_list/1)
      |> NIF.instrumenter_new()

    %Instrumenter{resource: resource}
  end

  @spec start(t) :: :ok | :error
  def start(%Instrumenter{} = inst) do
    NIF.instrumenter_start(inst.resource)
  end

  @spec stop(t) :: :ok | :error
  def stop(%Instrumenter{} = inst) do
    NIF.instrumenter_stop(inst.resource)
  end

  @spec submit_trace(t, Trace.t) :: :ok | :error
  def submit_trace(%Instrumenter{} = inst, %Trace{} = trace) do
    NIF.instrumenter_submit_trace(inst.resource, trace.resource)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(inst, _opts) do
      concat ["#Skylight.Instrumenter<", hash(inst), ">"]
    end

    defp hash(inst) do
      inst
      |> :erlang.phash2()
      |> :binary.encode_unsigned()
      |> Base.encode16(case: :lower)
    end
  end
end
