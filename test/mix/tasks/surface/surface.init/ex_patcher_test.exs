defmodule Mix.Tasks.Surface.Init.ExPatcherTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.ExPatcher

  test "find_call_with_args_and_opt" do
    code = """
    config :my_app, MyAppWeb.Endpoint,
      some_key: 1

    # Watch static and templates for browser reloading.
    config :my_app, MyAppWeb.Endpoint,
      live_reload: [
        patterns: [
          ~r"priv/gettext/.*(po)$"
        ]
      ]
    """

    config =
      code
      |> ExPatcher.parse_string!()
      |> ExPatcher.find_call_with_args_and_opt(:config, [":my_app", "MyAppWeb.Endpoint"], [:live_reload])
      |> ExPatcher.node_to_string()

    assert config == """
           # Watch static and templates for browser reloading.
           config :my_app, MyAppWeb.Endpoint,
             live_reload: [
               patterns: [
                 ~r"priv/gettext/.*(po)$"
               ]
             ]\
           """
  end

  test "find_call_with_args_and_opt with def" do
    code = """
    defmodule MyAppWeb.ErrorHelpers do
      def translate_error({msg, opts}) do
        IO.inspect({msg, opts})
      end
    end
    """

    config =
      code
      |> ExPatcher.parse_string!()
      |> ExPatcher.enter_call(:defmodule)
      |> ExPatcher.find_def(:translate_error)
      |> ExPatcher.node_to_string()

    assert config == """
           def translate_error({msg, opts}) do
             IO.inspect({msg, opts})
           end\
           """
  end

  test "find keyword value" do
    code = """
    [a: "A", b: "B"]
    """

    value =
      code
      |> ExPatcher.parse_string!()
      |> ExPatcher.find_keyword([:a])
      |> ExPatcher.value()
      |> ExPatcher.node_to_string()

    assert value == ~S("A")

    value =
      code
      |> ExPatcher.parse_string!()
      |> ExPatcher.find_keyword([:b])
      |> ExPatcher.value()
      |> ExPatcher.node_to_string()

    assert value == ~S("B")
  end

  test "find keyword with nested keys" do
    code = """
    [a: "A", b: [c: "C"]]
    """

    value =
      code
      |> ExPatcher.parse_string!()
      |> ExPatcher.find_keyword([:b, :c])
      |> ExPatcher.value()
      |> ExPatcher.node_to_string()

    assert value == ~S("C")
  end

  test "find_def" do
    code = """
    defmodule MyAppWeb do
      defmacro __using__(which) when is_atom(which) do
        apply(__MODULE__, which, [])
      end

      def surface_live_view do
        1
      end
    end
    """

    config =
      code
      |> ExPatcher.parse_string!()
      |> ExPatcher.enter_call(:defmodule)
      |> ExPatcher.find_def(:surface_live_view)
      |> ExPatcher.node_to_string()

    assert config == """
           def surface_live_view do
             1
           end\
           """
  end
end
