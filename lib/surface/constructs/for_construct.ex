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
     </#if>
     ```
     """}
  end

  def attribute_type(block, attribute, _)
      when block in [:default, "elseif"] and attribute in [:root, "condition"],
      do: :boolean

  def attribute_type("else", name, meta) when name in [:root, "condition"] do
    IOHelper.warn(
      "else does not accept a condition property",
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
end
