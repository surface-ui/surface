defmodule Surface.Compiler.NodeTranslator do
  @type parse_metadata :: %{line: non_neg_integer(), column: non_neg_integer(), file: binary()}

  @type block_info :: {:block_open, nil | Macro.t(), list(), parse_metadata()}
  @type tag_info :: {:tag_open, binary(), list(), parse_metadata()}
  @type context :: term()

  @type state :: %{
          caller: Macro.Env.t(),
          tags: list({tag_info() | block_info(), context()}),
          checks: keyword(boolean()),
          warnings: keyword(boolean())
        }

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

  @callback handle_text(value :: binary(), state :: state()) :: {any(), state()}
  @callback handle_comment(comment :: binary(), meta :: parse_metadata(), state :: state()) ::
              {any(), state()}

  @callback handle_node(
              name :: binary(),
              attrs :: list(),
              children :: list(),
              meta :: parse_metadata(),
              state :: state(),
              context :: context()
            ) :: {any(), state()}

  @callback handle_block(
              name :: binary(),
              expr :: any(),
              children :: list(),
              meta :: parse_metadata(),
              state :: state(),
              context :: context()
            ) :: {any(), state()}

  @callback handle_subblock(
              name :: binary(),
              expr :: any(),
              children :: list(),
              meta :: parse_metadata(),
              state :: state(),
              context :: context()
            ) :: {any(), state()}

  @callback handle_expression(
              expression :: binary(),
              meta :: parse_metadata(),
              state :: state()
            ) :: {any(), state()}
end
