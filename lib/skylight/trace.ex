defmodule Skylight.Trace do
  @moduledoc """
  A Skylight trace object.

  The internal structure of the `Skylight.Trace` struct is purposefully not
  documented as it's not public.
  """

  @type t :: %__MODULE__{
    resource: Skylight.resource,
  }

  @type handle :: non_neg_integer
  @type sql_flavor :: :generic | :mysql | :postgres

  alias __MODULE__
  alias Skylight.NIF

  defstruct [:resource]

  @sql_flavors %{
    generic: 0,
    mysql: 1,
    postgres: 2,
  }

  @doc """
  Creates a new trace

  The endpoint of the new trace is set to `endpoint`.

  ## Examples

      Skylight.Trace.new("MyController#my_endpoint")

  """
  @spec new(binary) :: t
  def new(endpoint) when is_binary(endpoint) do
    resource = NIF.trace_new(normalized_hrtime(), UUID.uuid4(), endpoint)
    %Trace{resource: resource}
  end

  @doc """
  Returns the time the given trace was started at.

  The returned time is in 1/10ms.
  """
  @spec get_started_at(t) :: non_neg_integer
  def get_started_at(%Trace{} = trace) do
    NIF.trace_start(trace.resource)
  end

  @doc """
  Returns the endpoint of the given trace.
  """
  @spec get_endpoint(t) :: binary
  def get_endpoint(%Trace{} = trace) do
    NIF.trace_endpoint(trace.resource)
  end

  @doc """
  Sets the endpoint of the given trace.

  The trace is modified in place (no Erlang immutable data structures here), so
  use this carefully.
  """
  @spec set_endpoint(t, binary) :: :ok | :error
  def set_endpoint(%Trace{} = trace, endpoint) do
    NIF.trace_set_endpoint(trace.resource, endpoint)
  end

  @doc """
  Gets the UUID of the given trace.
  """
  @spec get_uuid(t) :: binary
  def get_uuid(%Trace{} = trace) do
    NIF.trace_uuid(trace.resource)
  end

  @doc """
  Sets the UUID of the given trace.

  The trace is modified in place (no Erlang immutable data structures here), so
  use this carefully.
  """
  @spec set_uuid(t, binary) :: :ok | :error
  def set_uuid(%Trace{} = trace, uuid) do
    NIF.trace_set_uuid(trace.resource, uuid)
  end

  @doc """
  Instruments the given trace, creating a new span and returning its handle.

  The returned handle will identify the created span for the duration of its
  lifetime. `category` is the category that will set for the new span.
  """
  @spec instrument(t, binary) :: handle
  def instrument(%Trace{} = trace, category) when is_binary(category) do
    NIF.trace_instrument(trace.resource, normalized_hrtime(), category)
  end

  @doc """
  Sets the title of the given span on the given `trace`.

  The target span is identified by its `handle` (the one returned by
  `instrument/2`). The trace (and the target span) are modified in place (no
  Erlang immutability heaven here), so use this carefully.
  """
  @spec set_span_title(t, handle, binary) :: :ok | :error
  def set_span_title(%Trace{} = trace, handle, title) when is_integer(handle) and is_binary(title) do
    NIF.trace_span_set_title(trace.resource, handle, title)
  end

  @doc """
  Sets the description of the given span on the given `trace`.

  The target span is identified by its `handle` (the one returned by
  `instrument/2`). The trace (and the target span) are modified in place (no
  Erlang immutability heaven here), so use this carefully.
  """
  @spec set_span_desc(t, handle, binary) :: :ok | :error
  def set_span_desc(%Trace{} = trace, handle, desc) when is_integer(handle) and is_binary(desc) do
    NIF.trace_span_set_desc(trace.resource, handle, desc)
  end

  @doc """
  Sets the SQL query for the given span.

  This function is used when a span represents an Ecto query; the given `sql` is
  lexed by the Skylight Rust code. `flavor` is the SQL flavor to be passed to
  the Rust code (its value is determined usually by the Ecto adapter being
  used).

  The target span is identified by its `handle` (the one returned by
  `instrument/2`). The trace (and the target span) are modified in place (no
  Erlang immutability heaven here), so use this carefully.
  """
  @spec set_span_sql(t, handle, binary, sql_flavor) :: :ok | :error
  def set_span_sql(%Trace{} = trace, handle, sql, flavor)
      when is_integer(handle) and is_binary(sql) and flavor in unquote(Map.keys(@sql_flavors)) do
    # The native library doesn't yet handle Postgres properly
    flavor = if flavor == :postgres, do: :generic, else: flavor
    NIF.trace_span_set_sql(trace.resource, handle, sql, @sql_flavors[flavor])
  end

  @doc """
  Mark the given span as done.

  The target span is identified by its `handle` (the one returned by
  `instrument/2`). The `trace` (and the target span) are modified in place (no
  Erlang immutability heaven here), so use this carefully.
  """
  @spec mark_span_as_done(t, handle) :: :ok | :error
  def mark_span_as_done(%Trace{} = trace, handle) when is_integer(handle) do
    NIF.trace_span_done(trace.resource, handle, normalized_hrtime())
  end

  @doc """
  Stores the given trace in the process dictionary.
  """
  @spec store(t) :: :ok
  def store(%Trace{} = trace) do
    Process.put(:skylight_trace, trace)
    :ok
  end

  @doc """
  Retrieves the trace stored in the process dictionary, or `nil` if no trace is
  stored.
  """
  @spec fetch() :: t | nil
  def fetch() do
    Process.get(:skylight_trace)
  end

  @doc """
  Removes the trace stored in the process dictionary.
  """
  @spec unstore() :: :ok
  def unstore() do
    Process.delete(:skylight_trace)
    :ok
  end

  # So, there's this: the current Rust API takes 1/10ms when it wants a
  # timestamp (e.g. when instrumenting a trace). sky_hrtime() (NIF.hrtime/0
  # here) returns nanoseconds though. This means we have to divide by 100_000
  # everytime we actually use this function.
  defp normalized_hrtime() do
    div(NIF.hrtime(), 100_000)
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
