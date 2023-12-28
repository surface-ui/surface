defmodule Surface.Formatter.Phases.BlockExceptions do
  @moduledoc """
             Handle exceptional case for blocks.
             """ && false

  @behaviour Surface.Formatter.Phase
  alias Surface.Formatter.Phase

  def run(nodes, _opts) do
    Phase.transform_elements_and_descendants(nodes, &transform_block/1)
  end

  def transform_block({:block, "case", expr, sub_blocks, %{has_sub_blocks?: true} = meta}) do
    # "case" is a special case because its sub blocks are indented, unlike `if`
    # and `for`; therefore, the last `:indent_one_less` needs to be removed from
    # the last sub-block and moved to the outer block.
    #
    # This code is a bit hacky but kept the rest of the architecture simpler.
    reversed_sub_blocks = Enum.reverse(sub_blocks)
    [last_sub_block | rest] = reversed_sub_blocks
    {:block, "match", match_expr, children, last_meta} = last_sub_block

    modified_sub_blocks = [
      {:block, "match", match_expr, Enum.slice(children, 0..-2//1), last_meta} | rest
    ]

    modified_sub_blocks = Enum.reverse(modified_sub_blocks)

    {:block, "case", expr, [:newline, :indent | modified_sub_blocks] ++ [:indent_one_less], meta}
  end

  def transform_block(node), do: node
end
