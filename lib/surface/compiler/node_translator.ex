defmodule Surface.Compiler.NodeTranslator do
  @type parse_metadata :: %{line: non_neg_integer(), column: non_neg_integer(), file: binary()}

  @type tag_info :: {:tag_open, binary, list(), parse_metadata(), context()}
  @type state :: %{
          caller: Macro.Env.t(),
          tags: list(tag_info()),
          checks: keyword(boolean()),
          warnings: keyword(boolean())
        }
  @type context :: term()

  @callback context_for_node(state :: state(), name :: binary(), meta :: parse_metadata()) ::
              context()
  @callback context_for_block(state :: state(), name :: binary(), meta :: parse_metadata()) ::
              context()
  @callback context_for_subblock(
              state :: state(),
              block_name :: :default | binary(),
              parent_context :: context(),
              meta :: parse_metadata()
            ) ::
              context()

  @callback handle_attribute(
              state :: state(),
              context :: context(),
              name :: binary() | atom(),
              value :: binary() | {:expr, binary(), parse_metadata()},
              attr_meta :: parse_metadata()
            ) :: any()

  @callback handle_init(state :: state()) :: state()

  @callback handle_literal(state :: state(), value :: binary()) :: {state(), any()}
  @callback handle_comment(state :: state(), comment :: binary(), meta :: parse_metadata()) ::
              {state(), any()}

  @callback handle_node(
              state :: state(),
              context :: context(),
              name :: binary(),
              attrs :: list(),
              children :: list(),
              meta :: parse_metadata()
            ) :: {state(), any()}

  @callback handle_block(
              state :: state(),
              context :: context(),
              name :: binary(),
              attrs :: list(),
              children :: list(),
              meta :: parse_metadata()
            ) :: {state(), any()}

  @callback handle_subblock(
              state :: state(),
              context :: context(),
              name :: binary(),
              attrs :: list(),
              children :: list(),
              meta :: parse_metadata()
            ) :: {state(), any()}

  @callback handle_interpolation(
              state :: state(),
              expression :: binary(),
              meta :: parse_metadata()
            ) :: {state(), any()}
end
