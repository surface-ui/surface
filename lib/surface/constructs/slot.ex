defmodule Surface.Constructs.Slot do
  use Surface.Construct

  def validate_subblock(:default), do: :ok

  def validate_subblock(name) do
    {:error,
     """
     #slot does not accept any sub blocks, but found <##{name}>
     """}
  end

  def attribute_type(:default, "name", _meta), do: :string
  def attribute_type(:default, "index", _meta), do: :integer
  def attribute_type(:default, "props", _meta), do: :explict_keyword

  def attribute_type(_block, _attribute, _meta) do
    # TODO: add warning for ignored property
    :ignore
  end

  def process(attributes, body, [], meta) do
    name = find_prop_value(attributes, "name", %Surface.AST.Literal{value: :default})
    index = find_prop_value(attributes, "index", %Surface.AST.Literal{value: 0})
    props = find_prop_value(attributes, "props", %Surface.AST.Literal{value: %{}})

    %Surface.AST.Slot{
      name: name,
      index: index,
      props: props,
      default: body,
      meta: meta
    }
  end
end
