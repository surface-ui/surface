defmodule Surface.Compiler.NodeTranslator do
  @type parse_metadata :: %{line: non_neg_integer(), column: non_neg_integer(), file: binary()}

  @typedoc """
  The token representing the open node for a block.

  The second element is nil if the block does not have an expression (i.e. `{#else}`), or

  {:block_open, expression, children, parse metadata}
  """
  @type block_info :: {:block_open, binary(), nil | binary(), parse_metadata()}
  @type tag_info :: {:tag_open, binary(), list(), parse_metadata()}
  @type context :: term()

  @type state :: %{
          caller: Macro.Env.t(),
          tags: list({tag_info() | block_info(), context()}),
          checks: keyword(boolean()),
          warnings: keyword(boolean())
        }

  @typedoc """
  A node translator can return anything to represent the node, or use `:ignore` to
  indicate that this node should be removed entirely from the result
  """
  @type result :: term() | :ignore

  @callback context_for_node(name :: binary(), meta :: parse_metadata(), state :: state()) ::
              context()
  @callback context_for_block(name :: binary(), meta :: parse_metadata(), state :: state()) ::
              context()
  @callback context_for_subblock(
              block_name :: :default | binary(),
              meta :: parse_metadata(),
              state :: state(),
              parent_context :: context()
            ) ::
              context()

  @callback handle_attribute(
              name :: binary() | atom(),
              value :: binary() | {:expr, binary(), parse_metadata()},
              attr_meta :: parse_metadata(),
              state :: state(),
              context :: context()
            ) :: any()

  @callback handle_block_expression(
              block_name :: :default | binary(),
              nil | {:expr, binary(), parse_metadata()},
              state :: state(),
              context :: context()
            ) :: any()

  @callback handle_init(state :: state()) :: state()

  @callback handle_text(value :: binary(), state :: state()) :: {result(), state()}
  @callback handle_comment(comment :: binary(), meta :: parse_metadata(), state :: state()) ::
              {result(), state()}

  @callback handle_node(
              name :: binary(),
              attrs :: list(),
              children :: list(),
              meta :: parse_metadata(),
              state :: state(),
              context :: context()
            ) :: {result(), state()}

  @callback handle_block(
              name :: binary(),
              expr :: any(),
              children :: list(),
              meta :: parse_metadata(),
              state :: state(),
              context :: context()
            ) :: {result(), state()}

  @callback handle_subblock(
              name :: binary(),
              expr :: any(),
              children :: list(),
              meta :: parse_metadata(),
              state :: state(),
              context :: context()
            ) :: {result(), state()}

  @callback handle_expression(
              expression :: binary(),
              meta :: parse_metadata(),
              state :: state()
            ) :: {result(), state()}
end
