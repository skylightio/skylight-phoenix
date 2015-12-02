defmodule Skylight.Ecto.Repo do
  @moduledoc """
  TODO
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @proxy_repo Keyword.fetch!(opts, :proxy_to)

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
        instrument queryable, fn -> @proxy_repo.all(queryable, opts) end
      end

      def get(queryable, id, opts \\ []) do
        instrument queryable, fn -> @proxy_repo.get(queryable, id, opts) end
      end

      def get!(queryable, id, opts \\ []) do
        instrument queryable, fn -> @proxy_repo.get!(queryable, id, opts) end
      end

      def get_by(queryable, clauses, opts \\ []) do
        instrument queryable, fn -> @proxy_repo.get_by(queryable, clauses, opts) end
      end

      def get_by!(queryable, clauses, opts \\ []) do
        instrument queryable, fn -> @proxy_repo.get!(queryable, clauses, opts) end
      end

      def one(queryable, opts \\ []) do
        instrument queryable, fn -> @proxy_repo.one(queryable, opts) end
      end

      def one!(queryable, opts \\ []) do
        instrument queryable, fn -> @proxy_repo.one!(queryable, opts) end
      end

      def update_all(queryable, updates, opts \\ []) do
        instrument queryable, :update_all, fn -> @proxy_repo.update_all(queryable, updates, opts) end
      end

      def delete_all(queryable, opts \\ []) do
        instrument queryable, :delete_all, fn -> @proxy_repo.delete_all(queryable, opts) end
      end

      def insert(model, opts \\ []) do
        instrument model, :insert, fn -> @proxy_repo.insert(model, opts) end
      end

      def update(model, opts \\ []) do
        instrument model, :update, fn -> @proxy_repo.update(model, opts) end
      end

      def delete(model, opts \\ []) do
        instrument model, :delete, fn -> @proxy_repo.delete(model, opts) end
      end

      def insert!(model, opts \\ []) do
        instrument model, :insert, fn -> @proxy_repo.insert!(model, opts) end
      end

      def update!(model, opts \\ []) do
        instrument model, :update, fn -> @proxy_repo.update!(model, opts) end
      end

      def delete!(model, opts \\ []) do
        instrument model, :delete, fn -> @proxy_repo.delete!(model, opts) end
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

      defp instrument(queryable, kind \\ :all, fun) do
        Skylight.Ecto.instrument(@proxy_repo, kind, queryable, fun)
      end
    end
  end
end
