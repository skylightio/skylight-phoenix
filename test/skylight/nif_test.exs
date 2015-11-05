defmodule Skylight.NIFTest do
  use ExUnit.Case

  alias Skylight.NIF

  @libskylight_path "native/skylight_x86_64-darwin/libskylight.dylib"

  test "load_libskylight/1" do
    # Let's try this first as if the library is already loaded, then it will
    # always return :already_loaded.
    assert {:error, :loading_failed} = NIF.load_libskylight("nonexistent_path")

    assert :ok = NIF.load_libskylight(@libskylight_path)
    assert :already_loaded = NIF.load_libskylight(@libskylight_path)
  end
end
