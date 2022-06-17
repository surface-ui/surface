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
             other: MapSet.new([])
           }

    assert vars == %{
             "--029d26f--css-background" => "@css.background",
             "--c8f42e0--padding" => "@padding"
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
           div.blog[data-s-myscope]:first-child { display: block }
           """

    assert selectors.elements == MapSet.new(["div.blog"])
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
end
