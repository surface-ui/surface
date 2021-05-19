defmodule Surface.Constructs.If do
  use Surface.Construct
  # alias Surface.Construct
  alias Surface.IOHelper

  def validate_subblock(name) when name in [:default, "else", "elseif"], do: :ok

  def validate_subblock(_name) do
    {:error,
     """
     #if only allows else and elseif sub blocks like so:
     ```
     <#if {...}>
       ...
     <#elseif {...}>
       ...
     <#else>
       ...
     </#if>
     ```
     """}
  end

  def attribute_type(block, attribute, _)
      when block in [:default, "elseif"] and attribute in [:root, "condition"],
      do: :boolean

  def attribute_type("else", name, meta) when name in [:root, "condition"] do
    IOHelper.warn(
      "else does not accept a condition property, did you mean to use <#elseif>?",
      meta.caller,
      fn _ -> meta.line end
    )

    :ignore
  end

  def attribute_type("else", name, meta) do
    IOHelper.warn(
      "#{name} is an unknown property for <#else> and will be ignored.",
      meta.caller,
      fn _ -> meta.line end
    )

    :ignore
  end

  def attribute_type(block, name, meta) do
    block_name = if block == :default, do: "if", else: block

    IOHelper.warn(
      """
      "#{name}" is an unknown attribute for <##{block_name}> and will be ignored.

      Did you mean to use either "condition" or the root prop?
      """,
      meta.caller,
      fn _ -> meta.line end
    )

    :ignore
  end

  def process(attributes, body, [], meta) do
    %Surface.AST.If{
      condition: find_condition(attributes),
      children: body,
      meta: meta
    }
  end

  def process(_attributes, _body, _blocks, meta) do
    IOHelper.compile_error(
      "sub block support is not implemented yet for #if",
      meta.file,
      meta.line
    )
  end

  defp find_condition([%Surface.AST.Attribute{value: value, meta: meta} | remainder]) do
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
        #if ignores duplicate/repeated attributes. Only the first condition found will be used.

        Hint: either specify the condition via a root property (`<#if { ... }>`) or via the \
        condition property (`<#if condition={ ... }>`), but not both (`<#if { ... } condition={ ... }>`)
        """,
        attr.meta.caller,
        fn _ -> attr.meta.line end
      )
    end)
  end
end
