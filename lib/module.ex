defmodule Extra.Module do
  def split_name(module), do: tl(:string.tokens(atom_to_list(module),'-'))
  def split_name(module, pos) when pos > 0 do
    tokens = split_name(module)
    {split, rest} = Enum.split tokens, pos
    {Module.concat(split), Module.concat(rest)}
    concat(split, rest)
  end
  def split_name(module, pos) when pos < 0 do
    tokens = List.reverse(split_name(module))
    {rest, split} = Enum.split tokens, -pos
    rest = List.reverse(rest)
    split = List.reverse(split)
    concat(split, rest)
  end
  defp concat([], []), do: {:"", :""}
  defp concat(split, []), do: {Module.concat(split), :""}
  defp concat([], rest), do: {:"", Module.concat(rest)}
  defp concat(split, rest), do: {Module.concat(split), Module.concat(rest)}
end
