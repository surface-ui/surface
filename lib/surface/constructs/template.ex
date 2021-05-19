defmodule Surface.Constructs.Template do
  use Surface.Construct

  def validate_subblock(:default), do: :ok

  def validate_subblock(name) do
    {:error,
     """
     #template does not accept any sub blocks, but found <##{name}>
     """}
  end

  def attribute_type(:default, "name", _meta), do: :string
  def attribute_type(:default, "let", _meta), do: :bindings

  def attribute_type(_block, _attribute, _meta) do
    # TODO: add warning for ignored property
    :ignore
  end

  def process(attributes, body, [], meta) do
    name = find_prop_value(attributes, "name", %Surface.AST.Literal{value: :default})
    let = find_prop_value(attributes, "let", %Surface.AST.Literal{value: %{}})

    %Surface.AST.Template{
      name: name,
      let: let,
      children: body,
      meta: meta
    }
  end
end
