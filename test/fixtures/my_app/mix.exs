defmodule MyApp.Mixfile do
  use Mix.Project

  def project do
    [app: :my_app,
     version: "0.0.1",
     deps: [{:skylight, path: "../../.."}]]
  end

  def application do
    [applications: []]
  end
end
