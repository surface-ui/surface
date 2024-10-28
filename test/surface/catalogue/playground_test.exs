defmodule Surface.Catalogue.PlaygroundTest do
  use Surface.ConnCase, async: true
  import Phoenix.ConnTest

  alias Surface.Catalogue.FakePlayground

  setup do
    start_supervised!({Phoenix.PubSub, name: Surface.Catalogue.PubSub})
    :ok
  end

  test "saves subject as metadata" do
    meta = Surface.Catalogue.get_metadata(FakePlayground)

    assert meta.subject == Surface.Components.FakeButton
  end

  test "saves user config" do
    config = Surface.Catalogue.get_config(FakePlayground)

    assert config[:catalogue] == Surface.Components.FakeCatalogue
  end

  test "subject is required" do
    code = """
    defmodule PlaygroundTest_subject_is_required do
      use Surface.Catalogue.Playground
    end
    """

    message = ~r"""
    code.exs:2:
    #{maybe_ansi("error:")} no subject defined for Surface.Catalogue.Playground

    #{maybe_ansi("hint:")} you can define the subject using the :subject option. Example:

      use Surface.Catalogue.Playground, subject: MyApp.MyButton
    """

    assert_raise Surface.CompileError, message, fn ->
      Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end
  end

  test "merge default values with custom props" do
    {:ok, _view, html} = live_isolated(build_conn(), FakePlayground)

    assert html =~ html_escape(~S(color: "white"))
    assert html =~ html_escape(~S(label: "My label"))
    assert html =~ html_escape(~S(type: "button"))
    assert html =~ html_escape(~S(map: %{info: "info"}))
  end

  defp html_escape(string) do
    string
    |> Phoenix.HTML.Engine.html_escape()
    |> to_string()
  end
end
