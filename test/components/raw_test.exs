defmodule Surface.Components.RawTest do
  use Surface.ConnCase

  alias Surface.Components.Raw

  test "<#Raw> does not translate any of its contents" do
    assigns = %{id: "1234"}

    html =
      render_surface do
        ~H"""
        <#Raw>
          <div>
            { @id }
          </div>
        </#Raw>
        """
      end

    assert html =~ """
             <div>
               { @id }
             </div>
           """
  end
end
