defmodule SkylightBootstrap.HTTP do
  @callback get(binary) :: {:ok, data :: binary} | {:error, reason :: term}

  @doc """
  Callback implementation of `SkylightBootstrap.HTTP.get/1`.
  """
  @spec get(binary) :: {:ok, binary} | {:error, term}
  def get(url) do
    request = {to_char_list(url), []}
    http_opts = [connect_timeout: 10_000, autoredirect: true]
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
