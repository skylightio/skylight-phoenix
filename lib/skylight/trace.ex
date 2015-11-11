defmodule Skylight.Trace do
  @moduledoc """
  A Skylight trace object.
  """

  @type t :: %__MODULE__{
    resource: Skylight.resource,
  }

  alias __MODULE__
  alias Skylight.NIF

  defstruct [:resource]

  @spec new(binary) :: t
  def new(endpoint) when is_binary(endpoint) do
    resource = NIF.trace_new(NIF.hrtime(), UUID.uuid4(), endpoint)
    %Trace{resource: resource}
  end

  @spec get_started_at(t) :: non_neg_integer
  def get_started_at(%Trace{} = trace) do
    NIF.trace_start(trace.resource)
  end

  @spec get_endpoint(t) :: binary
  def get_endpoint(%Trace{} = trace) do
    NIF.trace_endpoint(trace.resource)
  end

  @spec put_endpoint(t, binary) :: :ok | :error
  def put_endpoint(%Trace{} = trace, endpoint) do
    NIF.trace_set_endpoint(trace.resource, endpoint)
  end

  @spec get_uuid(t) :: binary
  def get_uuid(%Trace{} = trace) do
    NIF.trace_uuid(trace.resource)
  end

  @spec put_uuid(t, binary) :: :ok | :error
  def put_uuid(%Trace{} = trace, uuid) do
    NIF.trace_set_uuid(trace.resource, uuid)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Trace{} = trace, opts) do
      concat ["#Skylight.Trace<",
              "uuid: ", Skylight.Trace.get_uuid(trace),
              ", ",
              "endpoint: ", to_doc(Skylight.Trace.get_endpoint(trace), opts),
              ">"]
    end
  end
end
