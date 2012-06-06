defmodule Extra do
  defmacro __using__(_) do
    quote do 
      use Extra.Record
    end
  end
end