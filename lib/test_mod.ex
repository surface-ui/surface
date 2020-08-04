defmodule Outer do
  use Surface.Component

  context set field, :any, scope: :only_children

  def init_context(_assigns) do
    {:ok, field: "field from Outer"}
  end

  def render(assigns) do
    ~H"""
    <div>{{ @inner_content.([]) }}</div>
    """
  end
end

defmodule RenderContext do
  use Surface.Component

  def render(assigns) do
    ~H"""
    Context: {{ inspect(@__surface__.context) }}
    """
  end
end

defmodule Inner do
  use Surface.Component

  context get field, from: ContextTest.Outer
  context get field, from: ContextTest.InnerWrapper, as: :other_field

  def render(assigns) do
    ~H"""
    <span id="field">{{ @field }}</span>
    <span id="other_field">{{ @other_field }}</span>
    """
  end
end

defmodule TestView do
  use Surface.LiveView

  def render(assigns) do
    ~H"""
    <Outer>
      <Inner/>
    </Outer>
    <RenderContext/>
    """
  end
end
