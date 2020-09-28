defmodule Surface.Components.MarkdownTest do
  use ExUnit.Case, async: true

  import Surface
  import ComponentTestHelper
  alias Surface.Components.Markdown

  test "translate markdown into HTML" do
    assigns = %{}

    code = ~H"""
    <#Markdown>
      # Head 1
      Bold: **bold**
      Code: `code`
    </#Markdown>
    """

    assert render_static(code) =~ """
           <div>\
           <h1>
           Head 1</h1>
           <p>
           Bold: <strong>bold</strong>
           Code: <code class="inline">code</code></p>
           </div>
           """
  end

  test "setting the class" do
    assigns = %{}

    code = ~H"""
    <#Markdown class="markdown">
      # Head 1
    </#Markdown>
    """

    assert render_static(code) =~ """
           <div class="markdown">\
           <h1>
           Head 1</h1>
           </div>
           """
  end

  test "setting multiple classes" do
    assigns = %{}

    code = ~H"""
    <#Markdown class="markdown small">
      # Head 1
    </#Markdown>
    """

    assert render_static(code) =~ """
           <div class="markdown small">\
           <h1>
           Head 1</h1>
           </div>
           """
  end

  test "setting unwrap removes the wrapping <div>" do
    assigns = %{}

    code = ~H"""
    <#Markdown unwrap>
      # Head 1
    </#Markdown>
    """

    assert render_static(code) == """
           <h1>
           Head 1</h1>
           """
  end

  test "setting opts forward options to Earmark" do
    assigns = %{}

    code = ~H"""
    <#Markdown opts={{ code_class_prefix: "language-" }}>
      ```elixir
      code
      ```
    </#Markdown>
    """

    assert render_static(code) =~ """
           <pre><code class="elixir language-elixir">code</code></pre>
           """
  end
end

defmodule Surface.Components.MarkdownSyncTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import ComponentTestHelper
  alias Surface.Components.Markdown

  describe "config" do
    test ":default_class config" do
      using_config Markdown, default_class: "content" do
        html =
          render_live("""
          <#Markdown>
            # Head 1
          </#Markdown>
          """)

        assert html =~ """
               <div class="content"><h1>
               Head 1</h1></div>
               """
      end
    end

    test "override the :default_class config" do
      using_config Markdown, default_class: "content" do
        html =
          render_live("""
          <#Markdown class="markdown">
            # Head 1
          </#Markdown>
          """)

        assert html =~ """
               <div class="markdown"><h1>
               Head 1</h1></div>
               """
      end
    end

    test ":default_opts config" do
      using_config Markdown, default_opts: [code_class_prefix: "language-"] do
        html =
          render_live(~S"""
          <#Markdown>
            ```elixir
            var = 1
            ```
          </#Markdown>
          """)

        assert html =~ """
               <div><pre><code class="elixir language-elixir">var = 1</code></pre></div>
               """
      end
    end

    test "property opts gets merged with global config :opts (overriding existing keys)" do
      using_config Markdown, default_opts: [code_class_prefix: "language-", smartypants: false] do
        html =
          render_live("""
          <#Markdown>
            "Elixir"
          </#Markdown>
          """)

        assert html =~ """
               <div><p>
               &quot;Elixir&quot;</p></div>
               """

        html =
          render_live("""
          <#Markdown opts={{ smartypants: true }}>
            "Elixir"

            ```elixir
            code
            ```
          </#Markdown>
          """)

        assert html =~
                 """
                 <div><p>
                 “Elixir”</p><pre><code class="elixir language-elixir">code</code></pre></div>
                 """
      end
    end
  end

  describe "error/warnings" do
    test "do not accept runtime expressions" do
      assigns = %{class: "markdown"}

      code = """
      <#Markdown
        class={{ @class }}>
        # Head 1
      </#Markdown>
      """

      message = ~r"""
      code:2: invalid value for property "class"

      Expected a string while evaluating {{ @class }}, got: nil

      Hint: properties of macro components can only accept static values like module attributes,
      literals or compile-time expressions. Runtime variables and expressions, including component
      assigns, cannot be avaluated as they are not available during compilation.
      """

      assert_raise(CompileError, message, fn ->
        capture_io(:standard_error, fn ->
          render_live(code, assigns)
        end)
      end)
    end

    test "show parsing errors/warnings at the right line" do
      assigns = %{class: "markdown"}

      code = """
      <#Markdown>
        Text
        Text `code
        Text
      </#Markdown>
      """

      output =
        capture_io(:standard_error, fn ->
          render_live(code, assigns)
        end)

      assert output =~ ~r"""
             Closing unclosed backquotes ` at end of input
               code:2:\
             """
    end
  end
end
