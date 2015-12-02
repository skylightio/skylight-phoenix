defmodule Skylight.Config do
  @moduledoc """
  Conveniences for reading, parsing, and manipulating the Skylight
  configuration.
  """

  @priv Application.app_dir(:skylight, "priv")
  @required ~w(authentication)a

  @doc """
  Reads the configuration.

  This function reads the configuration from the env of the `:skylight`
  application, replaces `{:system, var}` values with the value of the
  corresponding environment variable, sets default values for all the keys and
  turns the configuration in a map like:

      %{"SKYLIGHT_FOO" => "true",
        "SKYLIGHT_PATH" => "/path/to/skylight",
        ...}

  """
  @spec read() :: %{}
  def read do
    Application.get_all_env(:skylight) # [foo: :bar, baz: {:system, "QUUX"}]
    |> read_env_variables()            # [foo: :bar, baz: :quux]
    |> ensure_required()               # same as above, raising if required are not present
    |> merge_with_defaults()           # %{foo: :bar, baz: :quuz, def: :ault}
    |> to_env()                        # %{"SKYLIGHT_FOO" => "bar", ...}
  end

  defp read_env_variables(config) do
    config = Enum.map config, fn
      {key, {:system, var}} -> {key, System.get_env(var)}
      kv                    -> kv
    end

    Enum.reject(config, &match?({_, nil}, &1))
  end

  defp ensure_required(config) do
    Enum.each @required, fn key ->
      unless config[key] do
        raise ArgumentError, """
        key #{inspect key} was either not found in the config of the :skylight
        application or was set to {:system, ENV_VAR} and ENV_VAR was not found
        in the environment. The config was:

            #{inspect config}
        """
      end
    end

    config
  end

  defp merge_with_defaults(config) do
    Dict.merge(dynamic_defaults(), config)
  end

  defp to_env(config) do
    for {key, value} <- config, into: %{} do
      {to_env_key(key), to_env_value(value)}
    end
  end

  defp dynamic_defaults do
    %{
      daemon_exec_path: Path.join(@priv, "skylightd"),
      daemon_lib_path: @priv,
      sockdir_path: File.cwd!(),
    }
  end

  defp to_env_key(key) when is_atom(key) do
    "SKYLIGHT_" <> String.upcase(Atom.to_string(key))
  end

  defp to_env_value(val) do
    to_string(val)
  end
end
