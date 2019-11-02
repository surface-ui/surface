defmodule Surface.BaseComponent do
  alias Surface.BaseComponent.LazyContent

  @callback render_code(mod_str :: binary, attributes :: any, children_iolist :: any, mod :: module, caller :: Macro.Env.t) :: any

  defmodule DataContent do
    defstruct [:data, :component]

    defimpl Phoenix.HTML.Safe do
      def to_iodata(data) do
        data
      end
    end
  end

  defmodule LazyContent do
    defstruct [:func]

    defimpl Phoenix.HTML.Safe do
      def to_iodata(data) do
        data
      end
    end
  end

  defmacro __using__(_) do
    quote do
      use Surface.Properties

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      import Phoenix.HTML
    end
  end

  def lazy(func) do
    %LazyContent{func: func}
  end

  def lazy_render(content) do
    [%LazyContent{func: render}] = non_empty_children(content)
    render
  end

  def non_empty_children([]) do
    []
  end

  def non_empty_children({:safe, content}) do
    for child <- content, !is_binary(child) || String.trim(child) != "" do
      child
    end
  end

  def non_empty_children(%Phoenix.LiveView.Rendered{dynamic: content}) do
    for child <- content, !is_binary(child) || String.trim(child) != "" do
      child
    end
  end

  def children_by_type({:safe, content}, component) do
    for %DataContent{data: data, component: ^component} <- content do
      data
    end
  end

  def children_by_type(%Phoenix.LiveView.Rendered{dynamic: content}, component) do
    for %DataContent{data: data, component: ^component} <- content do
      data
    end
  end

  def pop_children_by_type({:safe, content}, component) do
    {children, rest} = Enum.reduce(content, {[], []}, fn child, {children, rest} ->
      case child do
        %DataContent{data: data, component: ^component} ->
          {[data|children], rest}
        _ ->
          {children, [child|rest]}
      end
    end)
    {Enum.reverse(children), {:safe, Enum.reverse(rest)}}
  end

  def pop_children_by_type(%Phoenix.LiveView.Rendered{dynamic: content} = block, component) do
    {children, rest} = Enum.reduce(content, {[], []}, fn child, {children, rest} ->
      case child do
        %DataContent{data: data, component: ^component} ->
          {[data|children], [[]|rest]}
        _ ->
          {children, [child|rest]}
      end
    end)
    {Enum.reverse(children), %Phoenix.LiveView.Rendered{block | dynamic: Enum.reverse(rest)}}
  end
end
