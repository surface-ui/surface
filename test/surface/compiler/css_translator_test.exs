defmodule Surface.Compiler.CSSTranslatorTest do
  use ExUnit.Case, async: true

  alias Surface.Compiler.CSSTranslator

  test "translate CSS" do
    css = """
    /* padding: s-bind(padding); */

    .root {
      --custom-color: s-bind('@css.background');
    }

    .a:has(> img) > b[class="btn"], c {
      padding: s-bind('@padding');
    }

    @media screen and (min-width: 1216px) {
      .blog{display:block;}
    }

    @tailwind utilities;
    """

    %{css: translated, selectors: selectors, vars: vars} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert selectors == %{
             elements: MapSet.new(["b", "c"]),
             classes: MapSet.new(["a", "blog", "root"]),
             ids: MapSet.new([]),
             other: MapSet.new([]),
             combined: MapSet.new([])
           }

    assert vars == %{
             "--029d26f--css-background" =>
               {"@css.background", %{column: 25, column_end: 43, line: 4, line_end: 4}},
             "--c8f42e0--padding" => {"@padding", %{column: 18, column_end: 29, line: 8, line_end: 8}}
           }

    assert translated == """
           /* padding: s-bind(padding); */

           .root[data-s-myscope] {
             --custom-color: var(--029d26f--css-background);
           }

           .a[data-s-myscope]:has(> img) > b[data-s-myscope][class="btn"], c[data-s-myscope] {
             padding: var(--c8f42e0--padding);
           }

           @media screen and (min-width: 1216px) {
             .blog[data-s-myscope]{display:block;}
           }

           @tailwind utilities;
           """
  end

  test "translate selector with element, class and pseudo-classe " do
    css = """
    div.blog:first-child { display: block }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           div[data-s-myscope].blog[data-s-myscope]:first-child { display: block }
           """

    assert selectors.elements == MapSet.new([])
    assert selectors.classes == MapSet.new([])
    assert selectors.combined == MapSet.new([MapSet.new([".blog", "div"])])
  end

  test ":deep" do
    css = """
    .a :deep(.b) {
      padding: 10px;
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert selectors.classes == MapSet.new(["a"])

    assert translated == """
           .a[data-s-myscope] .b {
             padding: 10px;
           }
           """
  end

  test "translate selector with multiple classes and pseudo-classes" do
    css = """
    .a[title="foo"]:first-child.b[title="bar"]:hover { display: block }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           .a[data-s-myscope][title="foo"]:first-child.b[data-s-myscope][title="bar"]:hover { display: block }
           """

    assert selectors.classes == MapSet.new([])
    assert selectors.combined == MapSet.new([MapSet.new([".a", ".b"])])
  end

  test "name variables using only the hash when in :prod" do
    css = """
    .a {
      padding: s-bind('@padding');
    }
    """

    %{css: translated, vars: vars} = CSSTranslator.translate!(css, scope_id: "myscope", env: :prod)

    assert vars == %{
             "--c8f42e0" => {"@padding", %{column: 18, column_end: 29, line: 2, line_end: 2}}
           }

    assert translated == """
           .a[data-s-myscope] {
             padding: var(--c8f42e0);
           }
           """
  end
end
