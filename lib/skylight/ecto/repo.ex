defmodule Skylight.Ecto.Repo do
  @moduledoc """
  TODO
  """

  defmacro __using__(_opts) do
    quote unquote: false do
      def log(entry) do
        Process.put(:ecto_log_entry, entry)
        super(entry)
      end

      defoverridable [log: 1]

      module_code = quote do
        # The repo we want to proxy to is the repository that calls this
        # `__using__` hook.
        @proxy_repo unquote(__MODULE__)

        def config do
          @proxy_repo.config
        end

        def start_link(opts \\ []) do
          @proxy_repo.start_link(opts)
        end

        def stop(pid, timeout \\ 5000) do
          @proxy_repo.stop(pid, timeout)
        end

        def all(queryable, opts \\ []) do
          instrument fn -> @proxy_repo.all(queryable, opts) end
        end

        def get(queryable, id, opts \\ []) do
          instrument fn -> @proxy_repo.get(queryable, id, opts) end
        end

        def get!(queryable, id, opts \\ []) do
          instrument fn -> @proxy_repo.get!(queryable, id, opts) end
        end

        def get_by(queryable, clauses, opts \\ []) do
          instrument fn -> @proxy_repo.get_by(queryable, clauses, opts) end
        end

        def get_by!(queryable, clauses, opts \\ []) do
          instrument fn -> @proxy_repo.get!(queryable, clauses, opts) end
        end

        def one(queryable, opts \\ []) do
          instrument fn -> @proxy_repo.one(queryable, opts) end
        end

        def one!(queryable, opts \\ []) do
          instrument fn -> @proxy_repo.one!(queryable, opts) end
        end

        def update_all(queryable, updates, opts \\ []) do
          instrument fn -> @proxy_repo.update_all(queryable, updates, opts) end
        end

        def delete_all(queryable, opts \\ []) do
          instrument fn -> @proxy_repo.delete_all(queryable, opts) end
        end

        def insert(model, opts \\ []) do
          instrument fn -> @proxy_repo.insert(model, opts) end
        end

        def update(model, opts \\ []) do
          instrument fn -> @proxy_repo.update(model, opts) end
        end

        def delete(model, opts \\ []) do
          instrument fn -> @proxy_repo.delete(model, opts) end
        end

        def insert!(model, opts \\ []) do
          instrument fn -> @proxy_repo.insert!(model, opts) end
        end

        def update!(model, opts \\ []) do
          instrument fn -> @proxy_repo.update!(model, opts) end
        end

        def delete!(model, opts \\ []) do
          instrument fn -> @proxy_repo.delete!(model, opts) end
        end

        def preload(model_or_models, preloads) do
          @proxy_repo.preload(model_or_models, preloads)
        end

        # Functions with no default values, where we can use defdelegate.
        defdelegate [__adapter__,
                     __query_cache__,
                     __repo__,
                     __pool__,
                     log(entry)], to: @proxy_repo

        defp instrument(fun) do
          Skylight.Ecto.instrument(@proxy_repo, fun)
        end
      end

      # We use `module_code` and `Module.create/2` instead of just defining the
      # MyApp.Repo.Skylight module with `defmodule Skylight` because if we use
      # `defmodule Skylight` then we can't call `Skylight.*` in the same
      # module. This way, we define the new module with its fully qualified
      # name, even if it's inside another module.
      Module.create(__MODULE__.Skylight, module_code, Macro.Env.location(__ENV__))
    end
  end
end
