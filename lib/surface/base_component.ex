defmodule Surface.BaseComponent do
  alias Surface.BaseComponent.Lazy

  @callback render_code(mod_str :: binary, attributes :: any, children_iolist :: any, mod :: module, caller :: Macro.Env.t) :: any

  defmodule DataContent do
    defstruct [:data, :component]
  end

  defmodule Lazy do
    defstruct [:func]
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
    %Lazy{func: func}
  end

  def non_empty_children([]) do
    []
  end

  def non_empty_children(block) do
    {:safe, content} = block
    for child <- content, !is_binary(child) || String.trim(child) != "" do
      child
    end
  end

  def children_by_type(block, component) do
    {:safe, content} = block
    for %DataContent{data: data, component: ^component} <- content do
      data
    end
  end

  def pop_children_by_type(block, component) do
    {:safe, content} = block
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
end

defimpl Phoenix.HTML.Safe, for: Surface.BaseComponent.DataContent do
  def to_iodata(data) do
    data
  end
end

defimpl Phoenix.HTML.Safe, for: Surface.BaseComponent.Lazy do
  def to_iodata(data) do
    data
  end
end
