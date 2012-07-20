defmodule Reload do
  defmacro __using__(_) do
    quote do 
      import Reload
    end
  end

  @doc """
  This function simplifies experimenting in elixir shell. 
  Typical usage scenario is like follows:
    iex(1)> use Reload
    []
    iex(2)> reload [My.Awesome.Elixir.Module]
    [{:module,My.Awesome.Elixir.Module}]
  """
  def reload(modules) when is_list(modules) do
    lc module inlist modules, do: reload(module)
  end
  def reload(module) do
    :code.delete(module)
    :code.purge(module)
    :code.load_file(module)
  end
end