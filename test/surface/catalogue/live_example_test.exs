defmodule Surface.Catalogue.LiveExampleTest do
  use Surface.Case

  alias Surface.Catalogue.FakeLiveExample
  alias Surface.Catalogue.FakeLiveExampleModuleDocFalse

  test "saves subject as metadata" do
    meta = Surface.Catalogue.get_metadata(FakeLiveExample)

    assert meta.subject == Surface.FakeComponent
  end

  test "saves render/1's content as metadata" do
    [meta] = Surface.Catalogue.get_metadata(FakeLiveExample).examples_configs

    assert Keyword.fetch!(meta, :code) == "The code\n"
  end

  test "saves user config" do
    config = Surface.Catalogue.get_config(FakeLiveExample)

    assert config[:title] == "A fake example"
  end

  test "saves render/1's content as metadata when moduledoc is false" do
    [meta] = Surface.Catalogue.get_metadata(FakeLiveExampleModuleDocFalse).examples_configs

    assert Keyword.fetch!(meta, :code) == "The code\n"
  end

  test "subject is required" do
    code = """
    defmodule ExampleTest_subject_is_required do
      use Surface.Catalogue.LiveExample
    end
    """

    message = ~r"""
    code\.exs:2:
    #{maybe_ansi("error:")} no subject defined for Surface\.Catalogue\.LiveExample

    #{maybe_ansi("hint:")} you can define the subject using the :subject option\. Example:

      use Surface\.Catalogue\.LiveExample, subject: MyApp.MyButton
    """

    assert_raise Surface.CompileError, message, fn ->
      Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end
  end
end
