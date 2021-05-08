defmodule Surface.Components.RawTest do
  use Surface.ConnCase

  import ExUnit.CaptureIO

  test "warn if deprecated <#Raw> is used" do
    id = :erlang.unique_integer([:positive]) |> to_string()
    module = "TestComponentThatUsesDeprecatedRawSyntax_#{id}"

    code = """
    defmodule #{module} do
      use Surface.Component
      alias Surface.Components.Raw

      prop label, :string, default: "My Label", required: true

      def render(assigns) do
        ~H\"""
        <#Raw>{ @label }</#Raw>
        \"""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           using <#Raw> has been deprecated and will be removed in future versions.

           Hint: replace `<#Raw>` with `<#raw>`
           """
  end

  test "<#raw> does not translate any of its contents" do
    assigns = %{id: "1234"}

    html =
      render_surface do
        ~H"""
        <#raw>
          <div>
            { @id }
          </div>
        </#raw>
        """
      end

    assert html =~ """
             <div>
               { @id }
             </div>
           """
  end
end
