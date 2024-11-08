defmodule Mix.Tasks.Compile.Surface.DefinitionsTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.Compile.Surface.Definitions
  alias Mix.Tasks.Compile.Surface

  @output_dir Path.join(File.cwd!(), "tmp/definitions")
  @components_file Path.join(@output_dir, "components.json")
  @components_by_name_file Path.join(@output_dir, "components_by_name.json")
  @common_file Path.join(@output_dir, "common.json")

  setup do
    if File.exists?(@output_dir) do
      File.rm_rf!(@output_dir)
    end

    on_exit(fn ->
      File.rm_rf!(@output_dir)
    end)

    %{opts: [definitions_output_dir: @output_dir]}
  end

  test "generate components.json", %{opts: opts} do
    refute File.exists?(@output_dir)

    {_, _, specs} =
      [
        to_beam_file(Components.Comp1),
        to_beam_file(Components.Comp2),
        to_beam_file(PhoenixComponents)
      ]
      |> Surface.extract_components_metadata()
      |> Surface.build_components_and_specs()

    assert run(specs, opts) == []

    assert File.read!(@components_file) == """
           [
             {
               "alias": "Comp1",
               "name": "Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp1"
             },
             {
               "alias": ".func_with_attr",
               "name": "Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp1.func_with_attr"
             },
             {
               "alias": "Comp2",
               "name": "Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp2"
             },
             {
               "alias": ".phoenix_func_with_attr",
               "name": "Mix.Tasks.Compile.Surface.DefinitionsTest.PhoenixComponents.phoenix_func_with_attr"
             }
           ]\
           """
  end

  describe "generate components_by_name.json" do
    test "generate specs for all surface and phoenix components", %{opts: opts} do
      refute File.exists?(@output_dir)

      {_, _, specs} =
        [
          to_beam_file(Components.Comp1),
          to_beam_file(Components.Comp2),
          to_beam_file(PhoenixComponents)
        ]
        |> Surface.extract_components_metadata()
        |> Surface.build_components_and_specs()

      assert run(specs, opts) == []

      components_by_name = File.read!(@components_by_name_file) |> Jason.decode!()

      assert Map.keys(components_by_name) == [
               "Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp1",
               "Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp1.func_with_attr",
               "Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp2",
               "Mix.Tasks.Compile.Surface.DefinitionsTest.PhoenixComponents.phoenix_func_with_attr"
             ]
    end

    test "generate specs for surface components", %{opts: opts} do
      refute File.exists?(@output_dir)

      {_, _, specs} =
        [to_beam_file(Components.Comp1)]
        |> Surface.extract_components_metadata()
        |> Surface.build_components_and_specs()

      assert run(specs, opts) == []

      assert %{"Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp1" => specs} =
               File.read!(@components_by_name_file) |> Jason.decode!()

      # Module
      assert specs["module"] == "Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp1"

      # Source
      assert specs["source"] == "test/support/mix/tasks/compile/surface/definitions_test/components.ex"

      # Type
      assert specs["type"] == "surface"

      # Aliases
      assert %{
               "Comp1" => "Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp1",
               "Raw" => "Surface.Components.Raw",
               "MyEnum" => "Enum"
             } = specs["aliases"]

      # Docs
      assert specs["docs"] =~ "My component docs"

      # Imports
      assert %{
               "async_result" => "Phoenix.Component.async_result",
               "phoenix_func_with_attr" =>
                 "Mix.Tasks.Compile.Surface.DefinitionsTest.PhoenixComponents.phoenix_func_with_attr"
             } = specs["imports"]

      # Private functions components
      assert [%{"func" => "priv_func_with_attr", "type" => "defp"}] = specs["privates"]

      # Props
      assert specs["props"] ==
               [
                 %{
                   "doc" => "The label",
                   "line" => Mix.Tasks.Compile.Surface.DefinitionsTest.Components.Comp1.__get_prop__(:label).line,
                   "name" => "label",
                   "opts" => ":string, required: true",
                   "type" => "string"
                 }
               ]
    end

    test "generate specs for phoenix components", %{opts: opts} do
      refute File.exists?(@output_dir)

      {_, _, specs} =
        [to_beam_file(PhoenixComponents)]
        |> Surface.extract_components_metadata()
        |> Surface.build_components_and_specs()

      assert run(specs, opts) == []

      assert %{"Mix.Tasks.Compile.Surface.DefinitionsTest.PhoenixComponents.phoenix_func_with_attr" => specs} =
               File.read!(@components_by_name_file) |> Jason.decode!()

      # Module
      assert specs["module"] == "Mix.Tasks.Compile.Surface.DefinitionsTest.PhoenixComponents"

      # Source
      assert specs["source"] == "test/support/mix/tasks/compile/surface/definitions_test/phoenix_components.ex"

      # Type
      assert specs["type"] == "def"

      # Docs
      assert specs["docs"] =~ "## Attributes\n\n* `name`"

      # Attrs
      assert specs["attrs"] == [
               %{
                 "doc" => "Docs for func_with_attr/1",
                 "line" => 4,
                 "name" => "name",
                 "type" => ":string",
                 "required" => false
               }
             ]
    end
  end

  describe "generate common.json" do
    test "generate specs for generic/common metadata", %{opts: opts} do
      refute File.exists?(@output_dir)
      assert run([], opts) == []
      assert common = File.read!(@common_file) |> Jason.decode!()

      assert Enum.sort(Map.keys(common)) == [
               "component_directives",
               "directives_specs",
               "macro_component_directives",
               "slot_directives",
               "slot_entry_directives",
               "slot_props_specs",
               "tag_attributes_specs",
               "tag_directives"
             ]
    end

    test "directives_specs", %{opts: opts} do
      refute File.exists?(@output_dir)
      assert run([], opts) == []
      assert %{"directives_specs" => directives_specs} = File.read!(@common_file) |> Jason.decode!()

      assert Enum.sort(Map.keys(directives_specs)) == [
               ":for",
               ":hook",
               ":if",
               ":let",
               ":on-blur",
               ":on-capture-click",
               ":on-change",
               ":on-click",
               ":on-click-away",
               ":on-focus",
               ":on-keydown",
               ":on-keyup",
               ":on-submit",
               ":on-viewport-bottom",
               ":on-viewport-top",
               ":on-window-blur",
               ":on-window-focus",
               ":on-window-keydown",
               ":on-window-keyup",
               ":show",
               ":values"
             ]

      assert %{
               "doc" => "Iterates over a list" <> _,
               "type" => "expression",
               "reference" => %{
                 "label" => "Surface's \"Directive\"",
                 "link" => "https://surface-ui.org/template_syntax#directives"
               }
             } = directives_specs[":for"]

      assert %{
               "doc" => "The `:on-blur` directive" <> _,
               "type" => "event",
               "reference" => %{
                 "label" => "Phoenix's \"Focus and Blur Events\"",
                 "link" => "https://hexdocs.pm/phoenix_live_view/bindings.html#focus-and-blur-events"
               }
             } = directives_specs[":on-blur"]
    end

    test "tag_attributes_specs", %{opts: opts} do
      refute File.exists?(@output_dir)
      assert run([], opts) == []
      assert %{"tag_attributes_specs" => tag_attributes_specs} = File.read!(@common_file) |> Jason.decode!()

      assert Enum.sort(Map.keys(tag_attributes_specs)) == [
               "phx-blur",
               "phx-capture-click",
               "phx-change",
               "phx-click",
               "phx-click-away",
               "phx-focus",
               "phx-keydown",
               "phx-keyup",
               "phx-submit",
               "phx-viewport-bottom",
               "phx-viewport-top",
               "phx-window-blur",
               "phx-window-focus",
               "phx-window-keydown",
               "phx-window-keyup"
             ]

      assert %{
               "doc" => "The `phx-blur` attribute" <> _,
               "type" => "event",
               "reference" => %{
                 "label" => "Phoenix's \"Focus and Blur Events\"",
                 "link" => "https://hexdocs.pm/phoenix_live_view/bindings.html#focus-and-blur-events"
               }
             } = tag_attributes_specs["phx-blur"]
    end

    test "tag_directives", %{opts: opts} do
      refute File.exists?(@output_dir)
      assert run([], opts) == []
      assert %{"tag_directives" => tag_directives} = File.read!(@common_file) |> Jason.decode!()

      assert Enum.sort(tag_directives) == [
               ":for",
               ":hook",
               ":if",
               ":on-blur",
               ":on-capture-click",
               ":on-change",
               ":on-click",
               ":on-click-away",
               ":on-focus",
               ":on-keydown",
               ":on-keyup",
               ":on-submit",
               ":on-viewport-bottom",
               ":on-viewport-top",
               ":on-window-blur",
               ":on-window-focus",
               ":on-window-keydown",
               ":on-window-keyup",
               ":show",
               ":values"
             ]
    end

    test "component_directives", %{opts: opts} do
      refute File.exists?(@output_dir)
      assert run([], opts) == []
      assert %{"component_directives" => component_directives} = File.read!(@common_file) |> Jason.decode!()
      assert component_directives == [":if", ":for"]
    end

    test "macro_component_directives", %{opts: opts} do
      refute File.exists?(@output_dir)
      assert run([], opts) == []

      assert %{"macro_component_directives" => macro_component_directives} =
               File.read!(@common_file) |> Jason.decode!()

      assert macro_component_directives == [":if", ":for"]
    end

    test "slot_entry_directives", %{opts: opts} do
      refute File.exists?(@output_dir)
      assert run([], opts) == []
      assert %{"slot_entry_directives" => slot_entry_directives} = File.read!(@common_file) |> Jason.decode!()
      assert slot_entry_directives == [":let"]
    end

    test "slot_props_specs", %{opts: opts} do
      refute File.exists?(@output_dir)
      assert run([], opts) == []
      assert %{"slot_props_specs" => slot_props_specs} = File.read!(@common_file) |> Jason.decode!()

      assert %{
               "generator_value" => %{
                 "doc" => "Passes the value of the generator" <> _,
                 "reference" => %{
                   "label" => "Surface's \"Slot\" page",
                   "link" => "https://surface-ui.org/slots#slot-generators"
                 },
                 "type" => "expression"
               }
             } = slot_props_specs
    end
  end

  defp to_beam_file(mod) do
    File.cwd!()
    |> Path.join("_build/test/lib/surface/ebin/#{__MODULE__}.#{inspect(mod)}.beam")
    |> to_charlist()
  end
end