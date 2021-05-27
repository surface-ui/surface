defmodule Surface.Compiler.NodeTranslator do
  @moduledoc false
  alias Surface.Compiler.Tokenizer

  @type context :: term()

  @typedoc """
  A node translator can return anything to represent the node, or use `:ignore` to
  indicate that this node should be removed entirely from the result.
  """
  @type result :: term() | :ignore

  @callback context_for_node(name :: binary(), Tokenizer.tag_metadata(), Parser.state()) ::
              context()
  @callback context_for_block(name :: binary(), Tokenizer.block_metadata(), Parser.state()) ::
              context()
  @callback context_for_subblock(
              Tokenizer.block_name(),
              Tokenizer.block_metadata(),
              Parser.state(),
              parent_context :: context()
            ) ::
              context()

  @callback handle_attribute(
              Tokenizer.attribute_name(),
              value :: binary() | Tokenizer.expression(),
              Tokenizer.attribute_metadata(),
              Parser.state(),
              context :: context()
            ) :: result()

  @callback handle_block_expression(
              Tokenizer.block_name(),
              nil | Tokenizer.expression(),
              Parser.state(),
              context :: context()
            ) :: result()

  @callback handle_init(Parser.state()) :: Parser.state()

  @callback handle_text(value :: binary(), Parser.state()) :: {result(), Parser.state()}
  @callback handle_comment(
              comment :: binary(),
              meta :: Tokenizer.comment_metadata(),
              Parser.state()
            ) ::
              {result(), Parser.state()}

  @callback handle_node(
              name :: Tokenizer.tag_name(),
              attrs :: list(result()),
              children :: list(result()),
              meta :: Tokenizer.tag_metadata(),
              Parser.state(),
              context :: context()
            ) :: {result(), Parser.state()}

  @callback handle_block(
              Tokenizer.block_name(),
              nil | result(),
              children :: list(result()),
              Tokenizer.block_metadata(),
              Parser.state(),
              context :: context()
            ) :: {result(), Parser.state()}

  @callback handle_subblock(
              Tokenizer.block_name(),
              nil | result(),
              children :: list(result()),
              Tokenizer.block_metadata(),
              Parser.state(),
              context :: context()
            ) :: {result(), Parser.state()}

  @callback handle_expression(
              expression :: binary(),
              meta :: Tokenizer.metadata(),
              Parser.state()
            ) :: {result(), Parser.state()}
end
