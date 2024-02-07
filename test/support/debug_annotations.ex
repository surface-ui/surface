defmodule Surface.CompilerTest.DebugAnnotations do
  use Surface.Component, debug_heex_annotations: true

  def func_with_tag(assigns) do
    ~F[<div>func_with_tag</div>]
  end

  def func_with_only_text(assigns) do
    ~F[only_text]
  end

  def func_with_text_and_tag(assigns) do
    ~F"""
    text_before<br>text_after
    """
  end

  def func_with_multiple_root_tags(assigns) do
    ~F[<div>text 1</div><div>text 2</div>]
  end

  embed_sface "debug_annotations.sface"
end
