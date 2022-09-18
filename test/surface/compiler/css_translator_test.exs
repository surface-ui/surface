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
             "--029d26f" => {"@css.background", %{column: 25, column_end: 43, line: 4, line_end: 4}},
             "--c8f42e0" => {"@padding", %{column: 18, column_end: 29, line: 8, line_end: 8}}
           }

    assert translated == """
           /* padding: s-bind(padding); */

           .root[data-s-myscope] {
             --custom-color: var(--029d26f);
           }

           .a[data-s-myscope]:has(> img) > b[data-s-myscope][class="btn"], c[data-s-myscope] {
             padding: var(--c8f42e0);
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

  test "translate selector with functions with multiple arguments" do
    css = """
    .test {
      margin: min(100px, 200px);
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           .test[data-s-myscope] {
             margin: min(100px, 200px);
           }
           """

    assert selectors.classes == MapSet.new(["test"])
  end

  test "translate declaration with value containing commas" do
    css = """
    .Input [data-input] {
      font-feature-settings: 'case', 'cpsp' 0, 'dlig' 0, 'ccmp', 'kern';
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           .Input[data-s-myscope] [data-input] {
             font-feature-settings: 'case', 'cpsp' 0, 'dlig' 0, 'ccmp', 'kern';
           }
           """

    assert selectors.classes == MapSet.new(["Input"])
  end

  test "translate declaration with variants" do
    css = """
    a {
      @apply bg-sky-500 hover:bg-sky-700;
      @apply lg:[&:nth-child(3)]:hover:underline;
      @apply [&_p]:mt-4;
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           a[data-s-myscope] {
             @apply bg-sky-500 hover:bg-sky-700;
             @apply lg:[&:nth-child(3)]:hover:underline;
             @apply [&_p]:mt-4;
           }
           """

    assert selectors.elements == MapSet.new(["a"])
  end
end
