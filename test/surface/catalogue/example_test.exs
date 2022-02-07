defmodule Surface.Catalogue.ExampleTest do
  use ExUnit.Case

  alias Surface.Catalogue.FakeExample
  alias Surface.Catalogue.FakeExampleModuleDocFalse

  test "saves subject as metadata" do
    meta = Surface.Catalogue.get_metadata(FakeExample)

    assert meta.subject == Surface.Components.Form
  end

  test "saves render/1's content as metadata" do
    meta = Surface.Catalogue.get_metadata(FakeExample)

    assert meta.code == "The code\n"
  end

  test "saves user config" do
    config = Surface.Catalogue.get_config(FakeExample)

    assert config[:title] == "A fake example"
  end

  test "saves render/1's content as metadata when moduledoc is false" do
    meta = Surface.Catalogue.get_metadata(FakeExampleModuleDocFalse)

    assert meta.code == "The code\n"
  end

  test "subject is required" do
    code = """
    defmodule ExampleTest_subject_is_required do
      use Surface.Catalogue.Example
    end
    """

    message = """
    code.exs:2: no subject defined for Surface.Catalogue.Example

    Hint: You can define the subject using the :subject option. Example:

      use Surface.Catalogue.Example, subject: MyApp.MyButton
    """

    assert_raise CompileError, message, fn ->
      Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end
  end
end
