defmodule SkylightBootstrapTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import SkylightBootstrap.TestHelpers

  alias SkylightBootstrap, as: SB

  @arch "x86_64-darwin"
  archive_name = "skylight_#{@arch}.tar.gz"
  @archive_name archive_name

  defmodule TestHTTP do
    import SkylightBootstrap.TestHelpers
    @behaviour SkylightBootstrap.HTTP

    def get(_) do
      if Process.get(:skylight_http_error_out) do
        {:error, :an_error}
      else
        {:ok, File.read!(fixture_path(unquote(archive_name)))}
      end
    end
  end

  setup_all do
    Application.put_env(:skylight, :fetcher_http_module, TestHTTP)

    on_exit fn ->
      File.rm_rf!(fixture_path("archives"))
      File.rm_rf!(fixture_path("building"))
    end
  end

  test "fetch/1: unknown architecture" do
    msg = "unsupported architecture: nonexistent"
    assert SB.fetch(arch: "nonexistent") == {:error, msg}
  end

  test "fetch/1: failed HTTP request" do
    Process.put(:skylight_http_error_out, true)

    capture_log fn ->
      assert {:error, error} = SB.fetch()
      assert String.starts_with?(error, "Failed to fetch Skylight native artifacts from")
      assert String.ends_with?(error, ":an_error")
    end
  end

  test "fetch/1" do
    archives_dir = fixture_path("archives")
    File.rm_rf!(archives_dir)

    log = capture_log fn ->
      assert :ok = SB.fetch(arch: @arch, archives_dir: archives_dir)
    end

    assert log =~ "Attempting to fetch from"
    assert File.exists?(fixture_path("archives/#{@archive_name}"))
  end

  test "extract_and_move/1: the archive doesn't exist" do
    assert {:error, msg} = SB.extract_and_move(archives_dir: "nonexistent", arch: "foo")
    assert msg ==
      "the archive with Skylight artifacts in it was not found at nonexistent/skylight_foo.tar.gz"
  end

  test "extract_and_move/1: bad archive" do
    File.mkdir_p! fixture_path("archives")
    File.write! fixture_path("archives/#{@archive_name}"), "foo"
    assert {:error, msg} = SB.extract_and_move(archives_dir: fixture_path("archives"), arch: @arch)
    assert msg == "error while extracting the tar archive: Unexpected end of file"
  end

  test "extract_and_move/1" do
    archives_dir = fixture_path("archives")

    File.rm_rf!(archives_dir)
    File.mkdir_p!(archives_dir)
    File.cp!(fixture_path(@archive_name), Path.join(archives_dir, @archive_name))

    c_src = fixture_path("building/c_src")
    priv = fixture_path("building/priv")
    File.mkdir_p!(c_src)
    File.mkdir_p!(priv)

    opts = [archives_dir: archives_dir,
            arch: @arch,
            c_src_dir: c_src,
            priv_dir: priv,
            libskylight_name: "libskylight.dylib"]

    assert :ok = SB.extract_and_move(opts)

    assert File.exists?(Path.join(c_src, "skylight_dlopen.h"))
    assert File.exists?(Path.join(c_src, "skylight_dlopen.c"))
    assert File.exists?(Path.join(priv, "skylightd"))
    assert File.exists?(Path.join(priv, "libskylight.dylib"))
  end

  test "artifacts_already_exist?/1" do
    archives_dir = fixture_path("archives")
    opts = [archives_dir: archives_dir, arch: @arch]

    File.rm_rf!(archives_dir)

    refute SB.artifacts_already_exist?(opts)

    File.mkdir_p!(archives_dir)
    File.cp!(fixture_path(@archive_name), Path.join(archives_dir, @archive_name))

    assert SB.artifacts_already_exist?(opts)
  end
end
