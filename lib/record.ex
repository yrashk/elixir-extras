"""
The below code is largely based on the original Record module, 
with some modifications

Copyright (c) 2012 Plataformatec. See LICENSE file in Elixir.
"""
defmodule Extra.Record do
  defmacro __using__(_) do
    quote do
      import Kernel, except: [defrecord: 3]
      import Extra.Record
    end
  end
  @moduledoc """
  Functions to define and interact with Erlang records
  """

  @doc """
  Extract record information from an Erlang file and
  return the fields as a list of tuples.

  ## Examples

      defrecord FileInfo, Record.extract(:file_info, from_lib: "kernel/include/file.hrl")

  """
  def extract(name, opts) do
    Record.Extractor.retrieve(name, opts)
  end

  @doc """
  Main entry point for records definition.
  This is invoked directly by `Kernel.defrecord`.
  Returns the quoted expression of a module given by name.
  """
  defmacro defrecord(name, values, opts) do
    moduledoc  = Keyword.get(opts, :moduledoc, false)
    block      = Keyword.get(opts, :do)
    definition = Keyword.get(opts, :definition, Extra.Record.Definition)

    quote do
      defmodule unquote(name) do
        @moduledoc unquote(moduledoc)
        Extra.Record.define_functions(__ENV__, unquote(values), unquote(definition))
        unquote(block)
      end
    end
  end

  @doc false
  # Private endpoint that defines the functions for the Record.
  def define_functions(env, values, definition) do
    # Escape the values so they are valid syntax nodes
    values = Macro.escape(values)

    contents = [
      reflection(env, values),
      getters_and_setters(values, 1, [], definition),
      initializers(values),
      converters(values)
    ]

    Module.eval_quoted env, contents
  end

  # Define __record__/1 and __record__/2 as reflection functions
  # that returns the record names and fields.
  #
  # Note that fields are *not* keywords. They are in the same
  # order as given as parameter and reflects the order of the
  # fields in the tuple.
  #
  # ## Examples
  #
  #     defrecord FileInfo, atime: nil, mtime: nil
  #
  #     FileInfo.__record__(:name)   #=> FileInfo
  #     FileInfo.__record__(:fields) #=> [atime: nil, mtime: nil]
  #
  defp reflection(env, values) do
    quote do
      def __record__(kind),       do: __record__(kind, nil)
      def __record__(:name, _),   do: unquote(env.module)
      def __record__(:fields, _), do: unquote(values)
    end
  end

  # Define initializers methods. For a declaration like:
  #
  #     defrecord FileInfo, atime: nil, mtime: nil
  #
  # It will define three methods:
  #
  #     def new() do
  #       new([])
  #     end
  #
  #     def new([]) do
  #       { FileInfo, nil, nil }
  #     end
  #
  #     def new(opts) do
  #       { FileInfo, Keyword.get(opts, :atime), Keyword.get(opts, :mtime) }
  #     end
  #
  defp initializers(values) do
    defaults = Enum.map values, elem(&1, 2)

    # For each value, define a piece of code that will receive
    # an ordered dict of options (opts) and it will try to fetch
    # the given key from the ordered dict, falling back to the
    # default value if one does not exist.
    selective = Enum.map values, fn {k,v} ->
      quote do: Keyword.get(opts, unquote(k), unquote(v))
    end

    quote do
      def new(), do: new([])
      def new([]), do: { __MODULE__, unquote_splicing(defaults) }
      def new(opts) when is_list(opts), do: { __MODULE__, unquote_splicing(selective) }
      def new(tuple) when is_tuple(tuple), do: setelem(tuple, 1, __MODULE__)

      defoverridable [new: 0, new: 1]
    end
  end

  # Define converters method(s). For a declaration like:
  #
  #     defrecord FileInfo, atime: nil, mtime: nil
  #
  # It will define one method, to_keywords, which will return a Keyword
  # 
  #    [atime: nil, mtime: nil]
  #
  defp converters(values) do
    sorted = Keyword.new values, fn({ k, _ }) ->
      index = Enum.find_index(values, fn({ x, _ }) -> x == k end)
      { k, quote(do: :erlang.element(unquote(index + 1), record)) }
    end

    quote do
      def to_keywords(record) do
        unquote(sorted)
      end
    end
  end

  # Implement getters and setters for each attribute.
  # For a declaration like:
  #
  #     defrecord FileInfo, atime: nil, mtime: nil
  #
  # It will define four methods:
  #
  #     def :atime.(record) do
  #       elem(record, 2)
  #     end
  #
  #     def :atime.(record, value) do
  #       setelem(record, 2, value)
  #     end
  #
  #     def :mtime.(record) do
  #       elem(record, 3)
  #     end
  #
  #     def :mtime.(record, value) do
  #       setelem(record, value, 3)
  #     end
  #
  # `element` and `setelement` will simply get and set values
  # from the record tuple. Notice that `:atime.(record)` is just
  # a dynamic way to say `atime(record)`. We need to use this
  # syntax as `unquote(key)(record)` wouldn't be valid (as Elixir
  # allows you to parenthesis just on specific cases as `foo()`
  # and `foo.bar()`)
  defp getters_and_setters([{ key, default }|t], i, acc, definition) do
    i = i + 1
    functions = definition.functions_for(key, default, i)
    getters_and_setters(t, i, [functions | acc], definition)
  end

  defp getters_and_setters([], _i, acc, _), do: acc
end

defmodule Extra.Record.Definition do
  @moduledoc false

  # Main entry point. It defines both default functions
  # via `default_for` and extensions via `extension_for`.
  def functions_for(key, default, i) do
    [
      default_for(key, default, i),
      extension_for(key, default, i)
    ]
  end

  # Skip the __exception__ for defexception.
  def default_for(:__exception__, _default, _i) do
    nil
  end

  # Define the default functions for each field.
  def default_for(key, _default, i) do
    bin_update = "update_" <> atom_to_binary(key)
    update     = binary_to_atom(bin_update)
    overridable = Keyword.from_enum([{key, 1}, {key, 2}, {update, 2}])

    quote do
      def unquote(key).(record) do
        :erlang.element(unquote(i), record)
      end

      def unquote(key).(value, record) do
        :erlang.setelement(unquote(i), record, value)
      end

      def unquote(update).(function, record) do
        current = :erlang.element(unquote(i), record)
        :erlang.setelement(unquote(i), record, function.(current))
      end

      defoverridable unquote(overridable)
    end
  end

  # Define extensions based on the default type.
  def extension_for(key, default, i) when is_list(default) do
    bin_key = atom_to_binary(key)
    prepend = :"prepend_#{bin_key}"
    merge   = :"merge_#{bin_key}"
    overridable = Keyword.from_enum([{prepend, 2}, {merge, 2}])

    quote do
      def unquote(prepend).(value, record) do
        current = :erlang.element(unquote(i), record)
        :erlang.setelement(unquote(i), record, value ++ current)
      end

      def unquote(merge).(value, record) do
        current = :erlang.element(unquote(i), record)
        :erlang.setelement(unquote(i), record, Keyword.merge(current, value))
      end

      defoverridable unquote(overridable)
    end
  end

  def extension_for(key, default, i) when is_number(default) do
    bin_key   = atom_to_binary(key)
    increment = :"increment_#{bin_key}"
    overridable = Keyword.from_enum([{increment, 2}])

    quote do
      def unquote(increment).(value // 1, record) do
        current = :erlang.element(unquote(i), record)
        :erlang.setelement(unquote(i), record, current + value)
      end

      defoverridable unquote(overridable)
    end
  end

  def extension_for(_, _, _), do: nil
end
