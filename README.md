# DirewolfPhoenixAgent

**TODO: Add description**

## Installation

  1. Add Skylight to your [list of dependencies](http://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-apps.html#external-dependencies).

  2. Add Skylight to your [applications array](http://elixir-lang.org/getting-started/mix-otp/supervisor-and-application.html#the-application-callback).

  3. Configure in `config/config.exs`:

      * Add Skylight configuration options

        ```elixir
        config :skylight,
          authentication: {:system, "SKYLIGHT_AUTHENTICATION"}
        ```

      * Set up as an instrumenter for your Endpoint:

        ```elixir
        config :my_app, MyApp.Endpoint,
          instrumenters: [Skylight] # Add this line to existing config
        ```

  4. Add Plug to Endpoint (`lib/APP/endpoint.ex`)

      ```elixir
      defmodule MyApp.Endpoint do
        # Add before first plug
        plug Skylight.Plug
      end
      ```

  5. Set up Ecto:

      * In `lib/APP/repo.ex`

        ```elixir
        defmodule MyApp.Repo do
          use Skylight.Ecto.Repo # Add this line
        end
        ```

      * In `web/web.ex`

        Replace references to:

        ```elixir
        alias MyApp.Repo
        ```

        with

        ```elixir
        alias MyApp.Repo.Skylight, as: Repo
        ```


## Development

```shell
$ mix deps.get
$ mix skylight.fetch
$ DIREWOLF_PHOENIX_TOKEN=TEST_APP_AUTH_TOKEN mix test
```

## Notes

If you have issues with crypto/OpenSSL try installing Erlang from https://packages.erlang-solutions.com/erlang/.
