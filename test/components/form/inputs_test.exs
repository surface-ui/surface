defmodule Surface.Components.Form.InputsTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.TextInput

  defmodule Parent do
    defmodule Child do
      use Ecto.Schema

      embedded_schema do
        field(:name, :string)
      end

      def changeset(cs_or_map, data), do: Ecto.Changeset.cast(cs_or_map, data, [:name])
    end

    use Ecto.Schema

    embedded_schema do
      embeds_many(:children, Child)
    end

    def changeset(cs_or_map \\ %__MODULE__{}, data),
      do:
        Ecto.Changeset.cast(cs_or_map, data, [])
        |> Ecto.Changeset.cast_embed(:children)
  end

  test "using generated form received as slot props" do
    html =
      render_surface do
        ~F"""
        <Form for={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children} :let={form: f}>
            <TextInput form={f} field="name" />
            <TextInput form={f} field="email" />
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
             <input id="parent_children_name" name="parent[children][name]" type="text">
             <input id="parent_children_email" name="parent[children][email]" type="text">
           </form>
           """
  end

  test "if the index is received as a slot prop" do
    cs = Parent.changeset(%{children: [%{name: "first"}, %{name: "second"}]})

    html =
      render_surface do
        ~F"""
        <Form for={cs} as={:cs} opts={csrf_token: "test"}>
          <Inputs for={:children} :let={index: idx}>
            <div>index: <span>{idx}</span></div>
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
               <div>index: <span>0</span></div>
               <div>index: <span>1</span></div>
           </form>
           """
  end

  test "using generated form stored in the Form context" do
    html =
      render_surface do
        ~F"""
        <Form for={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children}>
            <TextInput field="name" />
            <TextInput field="email" />
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
             <input id="parent_children_name" name="parent[children][name]" type="text">
             <input id="parent_children_email" name="parent[children][email]" type="text">
           </form>
           """
  end

  test "passing extra opts" do
    html =
      render_surface do
        ~F"""
        <Form for={:parent} opts={csrf_token: "test"}>
          <Inputs for={:children} opts={as: "custom_name"}>
            <TextInput field="name" />
            <TextInput field="email" />
          </Inputs>
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
             <input id="parent_children_name" name="custom_name[name]" type="text">
             <input id="parent_children_email" name="custom_name[email]" type="text">
           </form>
           """
  end
end
