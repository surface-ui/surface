# defmodule Surface.Engine do
#   alias Surface.Parser

#   def compile(path, _name) do
#     template =
#       path
#       |> File.read!()
#       |> Parser.parse(1)
#       |> Parser.to_iolist(__ENV__)
#       |> IO.iodata_to_binary()
#       |> EEx.compile_string(engine: Phoenix.HTML.Engine, line: 1)

#     quote do
#       # import Surface.Parser

#       temple do: unquote(template)
#     end
#   end
# end
