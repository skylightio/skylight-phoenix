defmodule Skylight.Instrumenter do
  @moduledoc """
  A Skylight instrumenter object.

  The internal structure of the `Skylight.Instrumenter` struct is purposefully
  not documented as it's not public.
  """

  @type t :: %__MODULE__{
    resource: Skylight.resource,
  }

  alias __MODULE__
  alias Skylight.NIF
  alias Skylight.Trace

  defstruct [:resource]

  @doc """
  Creates a new instrumenter using the given environment.

  Only one instrumenter should be started per application (ideally in the
  application's `start/2` callback).
  """
  @spec new(%{}) :: t
  def new(env) when is_map(env) do
    resource =
      env
      |> Enum.flat_map(&Tuple.to_list/1)
      |> NIF.instrumenter_new()

    %Instrumenter{resource: resource}
  end

  @doc """
  Starts the given instrumenter.
  """
  @spec start(t) :: :ok | :error
  def start(%Instrumenter{} = inst) do
    NIF.instrumenter_start(inst.resource)
  end

  @doc """
  Stops the given instrumenter.
  """
  @spec stop(t) :: :ok | :error
  def stop(%Instrumenter{} = inst) do
    NIF.instrumenter_stop(inst.resource)
  end

  @doc """
  Submits the given trace on the given instrumenter.

  **Note**: submitting a trace will make the underlying Rust code **free out
  that trace**. This means that it's not possible to access `trace` through
  other Skylight functions after calling this function (this includes things
  like `inspect(trace)`, since Skylight defines the `Inspect` protocol for
  traces).
  """
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
