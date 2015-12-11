Code.require_file "./skylight_bootstrap/http.ex", __DIR__

defmodule SkylightBootstrap do
  @moduledoc """
  Bootstrapping code for Skylight.

  This module provides functions to bootstrap Skylight, meaning:

    * downloading the Skylight precompiled code from the Skylight servers
    * extracting the downloaded archive and moving the extracted files into
    * their correct locations (so that `:skylight` can be compiled correctly).

  Some functions in this module take a list of options as an argument; these
  options can be used to configure things like destination directories,
  architecture, and so on. The complete list of options is this.

    * `:arch` - (binary) the cpu/os architecture for the code to download (e.g.,
      `x86_64-darwin`). Defaults to the current architecture.
    * `:archives_dir` - (binary) the directory where the archive should be
      downloaded. Defaults to `MIX_PROJ_ROOT/tmp`.
    * `:c_src_dir` - (binary) the directory where the source C files should be
      moved to (so that `make` can compile `:skylight` using those
      files). Defaults to `MIX_PROJ_ROOT/c_src`.
    * `:priv_dir` - (binary) the `priv` directory where things like `skylightd`
      and `libskylight` should be moved to; this should be the `priv` directory
      at the root of the Mix project, and not the one returned by functions like
      `:code.priv_dir/1`. Defaults to `MIX_PROJ_ROOT/priv`.
    * `:libskylight_name` - (binary) the name of the `libskylight` file to
      extract from the archive. Defaults to `libskylight.SO_EXTENSION`, where
      the extension is determined based on the current OS.

  """

  alias SkylightBootstrap.HTTP
  require Logger

  @base_url "https://s3.amazonaws.com/skylight-agent-packages/skylight-native"

  @version "0.7.0-629fc27"
  @checksums %{
    "x86-linux"     => "cd601750d0250d9e2cfed96fa9d4ac642a1b22053cf5ee5a7523da2f583fdf2d",
    "x86_64-linux"  => "eef6301799be9e1e6e70f71c59ac1449f52f65cf1dfe5c996762a42f31e08d5f",
    "x86_64-darwin" => "62b19c0f34e983d8d752b1b9514d427cc019cfdf2f3f6b2f1424cf06710330d8",
  }

  @doc """
  Fetches the precompiled code archive based on the given options.

  This function will write over the existing archive if such an archive exists.
  This function is only responsible for fetching the correct archive for the
  architecture in the options from the Skylight server; it's not responsible for
  extracting that archive or moving the extracted files around. See `build/1`
  for that.

  The supported options are described in the documentation for the
  `SkylightBootstrap` module. `{:error, _}` will be returned in case something
  goes wrong, like:

    * the architecture in the `:arch` option or the one of the current operating
      system/machine is not supported
    * there's a network error when fetching the precompiled code
    * the checksum of the downloaded archive doesn't match the expected one

  """
  @spec fetch(Keyword.t) :: :ok | {:error, binary}
  def fetch(opts \\ []) do
    opts = default_opts(opts)

    if supported_arch?(opts[:arch]) do
      fetch_for_arch(opts[:arch], opts)
    else
      {:error, "unsupported architecture: #{opts[:arch]}"}
    end
  end

  defp fetch_for_arch(arch, opts) do
    # Here, we're sure that `arch` is supported.
    destination = Path.join(opts[:archives_dir], basename(opts))
    source_url  = source_url(opts)
    checksum    = Map.fetch!(@checksums, arch)

    # Create the destination directory if it doesn't exist already
    prepare_destination(destination)

    Logger.debug "Attempting to fetch from #{source_url}"

    case http_module().get(source_url) do
      {:ok, contents} ->
        case verify_checksum(checksum, contents) do
          :ok -> File.write!(destination, contents)
          err -> err
        end
      {:error, reason} ->
        {:error, "failed to fetch from #{source_url}: #{inspect reason}"}
    end
  end

  defp supported_arch?(arch) when arch in unquote(Map.keys(@checksums)),
    do: true
  defp supported_arch?(_arch),
    do: false

  @doc """
  Extracts the archive specified by the `opts` and moves the extracted files
  around.

  The supported options are described in the documentation for the
  `SkylightBootstrap` module. `{:error, _}` will be returned in case something
  goes wrong, like:

    * the archive doesn't exist
    * the archive is not a valid tar archive

  """
  @spec extract_and_move(Keyword.t) :: :ok | {:error, binary}
  def extract_and_move(opts \\ []) do
    opts    = default_opts(opts)
    archive = Path.join(opts[:archives_dir], basename(opts))

    if File.exists?(archive) do
      do_extract_and_move(archive, opts)
    else
      {:error, "the archive with Skylight artifacts in it was not found at #{archive}"}
    end
  end

  defp do_extract_and_move(archive, opts) do
    case :erl_tar.extract(archive, [:compressed, cwd: opts[:archives_dir]]) do
      :ok ->
        move_extracted_files(opts)
      {:error, reason} ->
        msg = :erl_tar.format_error(reason)
        {:error, "error while extracting the tar archive: #{msg}"}
    end
  end

  @spec arch_and_os() :: binary
  defp arch_and_os do
    arch = :erlang.system_info(:system_architecture) |> to_string()

    [cpu, rest] = String.split(arch, "-", parts: 2)

    os = cond do
      rest =~ "linux"                     -> "linux"
      rest =~ "darwin" or rest =~ "apple" -> "darwin"
    end

    result = "#{cpu}-#{os}"

    unless result in Map.keys(@checksums) do
      raise "unsupported architecture: #{result}"
    end

    result
  end

  defp source_url(opts) do
    Enum.join([@base_url, @version, basename(opts)], "/")
  end

  defp basename(opts) do
    "skylight_#{opts[:arch]}.tar.gz"
  end

  defp http_module do
    Application.get_env(:skylight, :fetcher_http_module, HTTP)
  end

  defp verify_checksum(sha2, tar_gz) do
    tar_sha2 = sha2(tar_gz)

    if sha2 == tar_sha2 do
      :ok
    else
      {:error, "checksum mismatch: expected #{inspect sha2}, got #{inspect tar_sha2}"}
    end
  end

  defp sha2(term) do
    :crypto.hash(:sha256, term) |> Base.encode16(case: :lower)
  end

  defp move_extracted_files(opts) do
    Enum.each(files_to_extract(opts), &move_extracted_file(&1, opts))
  end

  defp move_extracted_file("skylight_dlopen." <> ext = file, opts) when ext in ~w(h c) do
    move_extracted_or_raise(file, Path.join(opts[:c_src_dir], file), opts)
  end

  defp move_extracted_file("skylightd" = file, opts) do
    move_extracted_or_raise(file, Path.join(opts[:priv_dir], file), opts)
  end

  defp move_extracted_file("libskylight." <> _ = file, opts) do
    move_extracted_or_raise(file, Path.join(opts[:priv_dir], file), opts)
  end

  defp move_extracted_or_raise(src, dst, opts) do
    case File.rename(Path.join(opts[:archives_dir], src), dst) do
      :ok ->
        :ok
      {:error, reason} ->
        formatted = :file.format_error(reason)
        raise "couldn't move #{src} to #{dst}: #{formatted}"
    end
  end

  defp so_ext do
    case :os.type do
      {:unix, :darwin} -> "dylib"
      {:unix, _}       -> "so"
      _                -> raise "unsupported OS"
    end
  end

  defp prepare_destination(destination) do
    destination |> Path.dirname() |> File.mkdir_p!()
    File.rm_rf!(destination)
  end

  defp files_to_extract(opts) do
    ["skylight_dlopen.c",
     "skylight_dlopen.h",
     "skylightd",
     opts[:libskylight_name]]
  end

  defp default_opts(opts) do
    opts
    |> Keyword.put_new(:arch, arch_and_os())
    |> Keyword.put_new(:archives_dir, Path.join(File.cwd!, "tmp"))
    |> Keyword.put_new(:c_src_dir, Path.join(File.cwd!, "c_src"))
    |> Keyword.put_new(:priv_dir, Path.join(File.cwd!, "priv"))
    |> Keyword.put_new(:libskylight_name, "libskylight.#{so_ext()}")
  end
end