defmodule Surface.Compiler.NodeTranslator do
  @type parse_metadata :: %{line: non_neg_integer(), column: non_neg_integer(), file: binary()}

  @type tag_info :: {:tag_open, binary, list(), parse_metadata()}
  @type state :: %{
          caller: Macro.Env.t(),
          tags: list(tag_info()),
          checks: keyword(boolean()),
          warnings: keyword(boolean())
        }

  @type type :: :tag | :void_tag | :attribute | :expression

  @callback handle_literal(state :: state(), value :: binary()) :: any()
  @callback handle_comment(state :: state(), comment :: binary()) :: any()
  @callback handle_attribute_expression(
              state :: state(),
              value :: binary(),
              meta :: parse_metadata()
            ) :: any()
  @callback handle_attribute(
              state :: state(),
              name :: binary() | atom(),
              value :: any(),
              meta :: parse_metadata()
            ) :: any()

  @callback handle_node(
              state :: state(),
              name :: binary(),
              attrs :: list(),
              children :: list(),
              meta :: parse_metadata()
            ) :: any()
  @callback handle_subblock(
              state :: state(),
              name :: binary(),
              attrs :: list(),
              children :: list(),
              meta :: parse_metadata()
            ) :: any()

  @callback handle_interpolation(
              state :: state(),
              expression :: binary(),
              meta :: parse_metadata()
            ) :: any()
  @callback handle_end(state :: state(), children :: list()) :: any()
end
