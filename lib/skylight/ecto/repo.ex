defmodule Skylight.Ecto.Repo do
  @moduledoc """
  TODO
  """

  defmacro __using__(_opts) do
    quote unquote: false do

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

        if function_exported?(@proxy_repo, :transaction, 3) do
          def transaction(fun_or_multi, opts \\ []) do
            @proxy_repo.transaction(fun_or_multi, opts);
          end

          defdelegate in_transaction?,  to: @proxy_repo
          defdelegate rollback,         to: @proxy_repo
        end

        def all(queryable, opts \\ []) do
          instrument fn -> @proxy_repo.all(queryable, opts) end
        end

        # Not sure if instrumentation will work correctly for this since it's lazy
        def stream(queryable, opts \\ []) do
          instrument fn -> @proxy_repo.stream(queryable, opts) end
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

        def aggregate(queryable, aggregate, field, opts \\ [])
            when aggregate in [:count, :avg, :max, :min, :sum] and is_atom(field) do
          instrument fn -> @proxy_repo.aggregate(queryable, aggregate, field, opts) end
        end

        def insert_all(schema_or_source, entries, opts \\ []) do
          instrument fn -> @proxy_repo.insert_all(schema_or_source, entries, opts) end
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

        def insert_or_update(changeset, opts \\ []) do
          instrument fn -> @proxy_repo.insert_or_update(changeset, opts) end
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

        def insert_or_update!(changeset, opts \\ []) do
          instrument fn -> @proxy_repo.insert_or_update!(changeset, opts) end
        end

        def delete!(model, opts \\ []) do
          instrument fn -> @proxy_repo.delete!(model, opts) end
        end

        def preload(struct_or_structs, preloads, opts \\ [])
        def preload(nil, _, _), do: nil
        def preload(struct_or_structs, preloads, opts) do
          @proxy_repo.preload(struct_or_structs, preloads, opts)
        end

        # Functions with no default values, where we can use defdelegate.
        # TODO: It may become possible to use `defdelegate` for more functions as of
        #   elixir 1.3 since that appears to support default values
        defdelegate __adapter__,      to: @proxy_repo
        defdelegate __query_cache__,  to: @proxy_repo
        defdelegate __repo__,         to: @proxy_repo
        defdelegate __pool__,         to: @proxy_repo
        defdelegate log(entry),       to: @proxy_repo
        defdelegate load(schema_or_types, data), to: @proxy_repo

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
