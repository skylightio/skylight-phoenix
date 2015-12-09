Code.require_file "./skylight_bootstrap/http.ex", __DIR__

defmodule SkylightBootstrap do
  alias SkylightBootstrap.HTTP
  require Logger

  @typep opts :: %{}

  @base_url "https://s3.amazonaws.com/skylight-agent-packages/skylight-native"

  @version "0.7.0-629fc27"
  @checksums %{
    "x86-linux"     => "cd601750d0250d9e2cfed96fa9d4ac642a1b22053cf5ee5a7523da2f583fdf2d",
    "x86_64-linux"  => "eef6301799be9e1e6e70f71c59ac1449f52f65cf1dfe5c996762a42f31e08d5f",
    "x86_64-darwin" => "62b19c0f34e983d8d752b1b9514d427cc019cfdf2f3f6b2f1424cf06710330d8",
  }

  def fetch(opts \\ []) do
    arch        = arch_and_os()
    destination = destination(opts)
    source_url  = source_url(opts)
    checksum = @checksums[arch] || throw({:error, "the current architecture (#{arch}) is not supported"})

    # Create the destination directory if it doesn't exist already
    destination |> Path.dirname() |> File.mkdir_p!()

    # Let's remove the existing file if it's there
    File.rm_rf!(destination)

    Logger.debug "Attempting to fetch from #{source_url}"

    case http_module().get(source_url) do
      {:ok, contents} ->
        verify_checksum(checksum, contents)
        File.write!(destination, contents)
      {:error, reason} ->
        throw {:error, "failed to fetch from #{source_url}: #{inspect reason}"}
    end
  end

  def build(opts \\ []) do
    archive = destination(opts)

    unless File.exists?(archive) do
      throw {:error, "the tar archive containing Skylight artifacts was not found at #{archive}"}
    end

    File.cd! Path.dirname(archive), fn ->
      case :erl_tar.extract(archive, [:compressed]) do
        :ok ->
          :ok
        {:error, reason} ->
          throw {:error, "error while extracting the tar archive: #{:erl_tar.format_error(reason)}"}
      end
    end

    move_extracted_files(Path.dirname(archive))
    File.rm_rf!("tmp")
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

  @spec source_url(opts) :: Path.t
  defp source_url(opts) do
    Enum.join([@base_url, @version, basename(opts)], "/")
  end

  @spec basename(opts) :: Path.t
  defp basename(_opts) do
    "skylight_#{arch_and_os()}.tar.gz"
  end

  @spec destination(opts) :: Path.t
  defp destination(opts) do
    Path.join([File.cwd!, "tmp", basename(opts)])
  end

  @spec http_module() :: module
  defp http_module do
    Application.get_env(:skylight, :fetcher_http_module, HTTP)
  end

  defp verify_checksum(sha2, tar_gz) do
    tar_sha2 = sha2(tar_gz)
    unless sha2 == tar_sha2 do
      throw {:error, "checksum mismatch: expected #{inspect sha2}, got #{inspect tar_sha2}"}
    end
  end

  defp sha2(term) do
    :crypto.hash(:sha256, term) |> Base.encode16(case: :lower)
  end

  defp move_extracted_files(extraction_dir) do
    files = ~w(skylight_dlopen.c skylight_dlopen.h skylightd libskylight.#{so_ext()})
    Enum.each(files, &move_extracted_file(extraction_dir, &1))
  end

  defp move_extracted_file(extraction_dir, "skylight_dlopen." <> ext = file) when ext in ["h", "c"] do
    File.rename(Path.join(extraction_dir, file), Path.join("c_src", file))
  end

  defp move_extracted_file(extraction_dir, "skylightd" = file) do
    File.rename(Path.join(extraction_dir, file), Path.join("priv", file))
  end

  defp move_extracted_file(extraction_dir, "libskylight." <> _ = file) do
    File.rename(Path.join(extraction_dir, file), Path.join("priv", file))
  end

  defp artifacts_already_exists? do
    files = ~w(c_src/skylight_dlopen.h
               c_src/skylight_dlopen.c
               priv/skylightd
               priv/libskylight.#{so_ext()})

    Enum.all?(files, &File.regular?/1)
  end

  defp so_ext do
    case :os.type do
      {:unix, :darwin} -> "dylib"
      {:unix, _}       -> "so"
      _                -> raise "unsupported OS"
    end
  end
end
