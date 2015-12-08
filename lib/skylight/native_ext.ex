defmodule Skylight.NativeExt do
  alias Skylight.NativeExt.HTTP
  require Logger

  @typep opts :: %{}

  @base_url "https://s3.amazonaws.com/skylight-agent-packages/skylight-native"

  # These things are stored in the libskylight.yml file in the Ruby version and
  # a bunch of checks are performed to ensure they're actually there. Here,
  # let's just be sure they're here :).
  # TODO remove the comment above!
  @version "0.7.0-629fc27"
  @checksums %{
    "x86-linux"     => "cd601750d0250d9e2cfed96fa9d4ac642a1b22053cf5ee5a7523da2f583fdf2d",
    "x86_64-linux"  => "eef6301799be9e1e6e70f71c59ac1449f52f65cf1dfe5c996762a42f31e08d5f",
    "x86_64-darwin" => "62b19c0f34e983d8d752b1b9514d427cc019cfdf2f3f6b2f1424cf06710330d8",
  }

  def fetch(opts \\ []) do
    arch        = arch_and_os()
    checksum    = @checksums[arch]
    destination = destination(opts)
    source_url  = source_url(opts)

    # Create the destination directory if it doesn't exist already
    destination |> Path.dirname() |> File.mkdir_p!()

    # Let's remove the existing file if it's there
    File.rm_rf!(destination)

    Logger.debug "Attempting to fetch from #{source_url}"

    case http_module().get(source_url) do
      {:error, reason} ->
        Logger.error "Failed to fetch from #{source_url}: #{inspect reason}"
      {:ok, contents} ->
        if verify_checksum(checksum, contents) do
          File.write!(destination, contents)
        end
    end
  end

  def build(opts \\ []) do
    archive = destination(opts)

    unless File.exists?(archive) do
      raise ".tar.gz Skylight archive not found"
    end

    File.cd! Path.dirname(archive), fn ->
      unless :erl_tar.extract(archive, [:compressed]) == :ok do
        raise "unable to extract the .tar.gz file"
      end
    end

    move_extracted_files(Path.dirname(archive))
    File.rm_rf!(archive)
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
  defp basename(opts) do
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
    if sha2 == sha2(tar_gz) do
      true
    else
      Logger.error "Checksum mismatch. Expected #{inspect sha2}, got #{inspect tar_gz}"
      false
    end
  end

  defp sha2(term) do
    :crypto.hash(:sha256, term) |> Base.encode16(case: :lower)
  end

  defp move_extracted_files(extraction_dir) do
    # TODO only check for the correct extension of libskylight
    files = ~w(skylight_dlopen.c skylight_dlopen.h libskylight.dylib libskylight.so skylightd)
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
end

defmodule Skylight.NativeExt.HTTP do
  @callback get(binary) :: {:ok, data :: binary} | {:error, reason :: term}

  def get(url) do
    request = {to_char_list(url), []}
    http_opts = [timeout: 10_000, autoredirect: true]
    opts      = [body_format: :binary]

    case :httpc.request(:get, request, http_opts, opts) do
      {:ok, {status_line, headers, body}} -> process_result(status_line, headers, body)
      {:error, _reason} = err             -> err
    end
  end

  defp process_result({_http_vsn, 200, 'OK'}, _headers, body) do
    {:ok, body}
  end

  defp process_result({_http_vsn, status_code, status_word}, _headers, _body) do
    {:error, {:http_error, status_code, status_word}}
  end
end
