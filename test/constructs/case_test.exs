defmodule Surface.Constructs.CaseTest do
  use Surface.ConnCase, async: true

  test "renders matching first sub-block" do
    assigns = %{value: [1, 2]}

    html =
      render_surface do
        ~F"""
        {#case @value}
          {#match [var | _]}
            <span>First match. Var: {var}</span>
          {#match _}
            <span>Last match</span>
        {/case}
        """
      end

    assert html =~ """
           <span>First match. Var: 1</span>
           """
  end

  test "renders matching last sub-block" do
    assigns = %{value: []}

    html =
      render_surface do
        ~F"""
        {#case @value}
          {#match [var | _]}
            <span>First match. Var: {var}</span>
          {#match _}
            <span>Last match</span>
        {/case}
        """
      end

    assert html =~ """
           <span>Last match</span>
           """
  end

  test "raise error if default sub-block has content" do
    code =
      quote do
        ~F"""
        <br>
        {#case @value}
          <span>First match</span>
        {#match _}
          <span>Last match</span>
        {/case}
        """
      end

    message = ~S(code:2: cannot have content between {#case ...} and {#match ...})

    assert_raise(CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "raise syntax error message at the correct line" do
    code =
      quote do
        ~F"""
        {#case @value}
          {#match [_]}
            <span>First</span>
          {#match {,}}
            <span>Last</span>
        {/case}
        """
      end

    message = ~S(code:4: syntax error before: ',')

    assert_raise(SyntaxError, message, fn ->
      compile_surface(code)
    end)
  end

  test "raise parser error message at the correct line" do
    code =
      quote do
        ~F"""
        {#case @value}
          {#match [_]}
            <span>First</span>
          {#match _}
            <span>The inner content
        {/case}
        """
      end

    message = ~S(code:5:14: expected closing node for <span> defined on line 5, got {/case})

    assert_raise(Surface.Compiler.ParseError, message, fn ->
      compile_surface(code)
    end)
  end
end
