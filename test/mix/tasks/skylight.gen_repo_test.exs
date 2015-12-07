defmodule Mix.Tasks.Skylight.GenRepoTest do
  use ExUnit.Case

  @fixture_app :my_app
  @fixture_app_path Path.join(File.cwd!(), "test/fixtures/my_app")

  setup do
    in_fixture_app fn ->
      File.mkdir_p!("lib/my_app")
    end

    on_exit fn ->
      in_fixture_app fn -> File.rm_rf!("lib/my_app/skylight.repo.ex") end
    end
  end

  test "writes lib/my_app/skylight.repo.ex with the correct contents" do
    in_fixture_app fn ->
      refute File.exists?("lib/my_app/skylight.repo.ex")

      run ~w(--repo MyApp.Repo)

      assert_receive {:mix_shell, :info, ["* creating lib/my_app"]}
      assert_receive {:mix_shell, :info, ["* creating lib/my_app/skylight.repo.ex"]}

      assert File.exists?("lib/my_app/skylight.repo.ex")
      assert File.read!("lib/my_app/skylight.repo.ex") == """
      defmodule MyApp.Skylight.Repo do
        use Skylight.Ecto.Repo, proxy_to: MyApp.Repo
      end
      """
    end
  end

  test "if the skylight.repo.ex files already exists, asks for confirmation before writing" do
    in_fixture_app fn ->
      File.write!("lib/my_app/skylight.repo.ex", "before overriding")

      send self(), {:mix_shell_input, :yes?, true}
      run ~w(--repo MyApp.Repo)

      assert File.read!("lib/my_app/skylight.repo.ex") =~ "defmodule MyApp.Skylight.Repo do"
    end
  end

  test "fails if no -r/--repo option for the proxy repo is given" do
    in_fixture_app fn ->
      msg = "You have to pass the proxy repo you want to use with -r/--repo."
             <> " See `mix help skylight.gen_repo`"
      assert_raise Mix.Error, msg, fn -> run([]) end
    end
  end

  test "fails for bad arguments" do
    bad_args = [~w(--rep Foo), ~w(--foo)]
    msg = "Invalid arguments. See `mix help skylight.gen_repo`"

    Enum.each bad_args, fn args ->
      assert_raise Mix.Error, msg, fn -> run(args) end
    end
  end

  defp in_fixture_app(fun) do
    Mix.Project.in_project(@fixture_app, @fixture_app_path, fn(_mixfile) -> fun.() end)
  end

  defp run(args) do
    Mix.Tasks.Skylight.GenRepo.run(args)
  end
end
