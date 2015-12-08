defmodule Skylight.NativeExtTest do
  use ExUnit.Case

  defmodule FakeHTTP do
    @behaviour Skylight.NativeExt.HTTP

    def get(_url) do
      {:ok, "foo"}
    end
  end

  setup_all do
    Application.put_env(:skylight, :fetcher_http_module, FakeHTTP)
  end

  test "fetch/0" do
  end
end
