defmodule Skylight.Trace do
  @moduledoc """
  A Skylight trace object.
  """

  @type t :: %__MODULE__{
    resource: Skylight.resource,
  }

  @type handle :: non_neg_integer

  alias __MODULE__
  alias Skylight.NIF

  defstruct [:resource]

  @spec new(binary) :: t
  def new(endpoint) when is_binary(endpoint) do
    resource = NIF.trace_new(normalized_hrtime(), UUID.uuid4(), endpoint)
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

  @spec instrument(t, binary) :: handle
  def instrument(%Trace{} = trace, category) when is_binary(category) do
    NIF.trace_instrument(trace.resource, normalized_hrtime(), category)
  end

  @spec set_span_title(t, handle, binary) :: :ok | :error
  def set_span_title(%Trace{} = trace, handle, title) when is_integer(handle) and is_binary(title) do
    NIF.trace_span_set_title(trace.resource, handle, title)
  end

  @spec set_span_desc(t, handle, binary) :: :ok | :error
  def set_span_desc(%Trace{} = trace, handle, desc) when is_integer(handle) and is_binary(desc) do
    NIF.trace_span_set_desc(trace.resource, handle, desc)
  end

  @spec mark_span_as_done(t, handle) :: :ok | :error
  def mark_span_as_done(%Trace{} = trace, handle) when is_integer(handle) do
    NIF.trace_span_done(trace.resource, handle, normalized_hrtime())
  end

  # So, there's this: the current Rust API takes 1/10ms when it wants a
  # timestamp (e.g. when instrumenting a trace). sky_hrtime() (NIF.hrtime/0
  # here) returns nanoseconds though. This means we have to divide by 100_000
  # everytime we actually use this function.
  defp normalized_hrtime() do
    NIF.hrtime() / 100_000
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
