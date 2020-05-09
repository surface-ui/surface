defmodule Surface.Components.MarkdownTest do
  use ExUnit.Case

  import Surface
  import ComponentTestHelper
  import ExUnit.CaptureIO

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
           <div>
           <h1>Head 1</h1>
           <p>Bold: <strong>bold</strong>
           Code: <code class="inline">code</code></p>
           </div>
           """
  end

  describe "global configuration" do
    test "use the :default_class config as the default class" do
      Application.put_env(:surface, :components, [
        {Markdown, default_class: "content"}
      ])

      html =
        render_live("""
        <#Markdown>
          # Head 1
        </#Markdown>
        """)

      Application.put_env(:surface, :components, [])

      assert html =~ """
             <div class="content"><h1>Head 1</h1></div>
             """
    end

    test "use the :default_opts config as the default Earmark options" do
      Application.put_env(:surface, :components, [
        {Markdown, default_opts: [code_class_prefix: "language-"]}
      ])

      html =
        render_live(~S"""
        <#Markdown>
          ```elixir
          var = 1
          ```
        </#Markdown>
        """)

      Application.put_env(:surface, :components, [])

      assert html =~ """
             <div><pre><code class="elixir language-elixir">var = 1</code></pre></div>
             """
    end
  end

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
             code:3:\
           """
  end

  describe "property :class" do
    test "sets the class attribute" do
      assigns = %{}

      code = ~H"""
      <#Markdown class="markdown">
        # Head 1
      </#Markdown>
      """

      assert render_static(code) =~ """
             <div class="markdown">
             <h1>Head 1</h1>
             </div>
             """
    end

    test "override the :default_class config" do
      Application.put_env(:surface, :components, [
        {Markdown, default_class: "content"}
      ])

      html =
        render_live("""
        <#Markdown class="markdown">
          # Head 1
        </#Markdown>
        """)

      Application.put_env(:surface, :components, [])

      assert html =~ """
             <div class="markdown"><h1>Head 1</h1></div>
             """
    end
  end

  describe "property :unwrap" do
    test "if true, removes the wrapping <div>" do
      assigns = %{}

      code = ~H"""
      <#Markdown unwrap>
        # Head 1
      </#Markdown>
      """

      assert render_static(code) == """
             <h1>Head 1</h1>
             """
    end
  end

  describe "property :opts" do
    test "forward options to Earmark" do
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

    test "gets merged with global config :opts (overrides existing keys)" do
      Application.put_env(:surface, :components, [
        {Markdown, default_opts: [code_class_prefix: "language-", smartypants: false]}
      ])

      html =
        render_live("""
        <#Markdown>
          "Elixir"
        </#Markdown>
        """)

      assert html =~ """
             <div><p>&quot;Elixir&quot;</p></div>
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
               <div><p>“Elixir”</p><pre><code class="elixir language-elixir">code</code></pre></div>
               """

      Application.put_env(:surface, :components, [])
    end
  end
end
