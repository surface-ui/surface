defmodule Surface.Constructs.For do
  use Surface.Construct
  alias Surface.IOHelper

  def validate_subblock(name) when name in [:default, "else"], do: :ok

  def validate_subblock(_name) do
    {:error,
     """
     #for only allows an optional else block like so:
     ```
     <#for {item <- @items}>
       ...
     <#else>
       ...
     </#for>
     ```
     """}
  end

  def attribute_type(block, attribute, _)
      when block in [:default] and attribute in [:root, "each"],
      do: :boolean

  def attribute_type("else", name, meta) do
    IOHelper.warn(
      "#{name} is an unknown property for <#else> and will be ignored.",
      meta.caller,
      fn _ -> meta.line end
    )

    :ignore
  end

  def attribute_type(:default, name, meta) do
    IOHelper.warn(
      """
      "#{name}" is an unknown attribute for <#for> and will be ignored.

      Did you mean to use either the "each" or the root prop?
      """,
      meta.caller,
      fn _ -> meta.line end
    )

    :ignore
  end

  def process(attributes, body, [], meta) do
    %Surface.AST.For{
      generator: find_each(attributes),
      children: body,
      meta: meta
    }
  end

  def process(_attributes, _body, _blocks, meta) do
    IOHelper.compile_error(
      "sub block support is not implemented yet for #for",
      meta.file,
      meta.line
    )
  end

  defp find_each([%Surface.AST.Attribute{value: value, meta: meta} | remainder]) do
    warn_ignored_attributes(remainder)

    case value do
      %Surface.AST.Literal{value: expression} ->
        %Surface.AST.AttributeExpr{original: expression, value: expression, meta: meta}

      %Surface.AST.AttributeExpr{} ->
        value
    end
  end

  defp warn_ignored_attributes(ignored_attributes) do
    Enum.each(ignored_attributes, fn attr ->
      IOHelper.warn(
        """
        #for ignores duplicate/repeated attributes. Only the first generator found will be used.

        Hint: either specify the generator via a root property (`<#for { ... }>`) or via the \
        each property (`<#for each={ ... }>`), but not both (`<#for { ... } each={ ... }>`)
        """,
        attr.meta.caller,
        fn _ -> attr.meta.line end
      )
    end)
  end
end
