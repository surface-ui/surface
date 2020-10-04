defmodule Surface.MacroComponent do
  @moduledoc """
  A low-level component which is responsible for translating its own
  content at compile time.
  """

  @doc """
  This function is called to expand a macro component into a
  set of Surface.AST nodes.
  """
  @callback expand(
              attributes :: [Surface.AST.Attribute.t()],
              children :: iodata(),
              meta :: Surface.AST.Meta.t()
            ) :: Surface.AST.t() | [Surface.AST.t()]

  alias Surface.IOHelper

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent, type: unquote(__MODULE__)

      use Surface.API, include: [:prop, :slot]
      @behaviour unquote(__MODULE__)
    end
  end

  @doc """
  Evaluates the values of the properties of a macro component.

  Usually called inside `translate/2` in order to retrieve the
  properties at compile-time.
  """
  def eval_static_props!(component, attributes, caller) do
    for attr <- attributes, into: %{} do
      eval_value(component, attr, caller)
    end
  end

  defp eval_value(
         _component,
         %Surface.AST.Attribute{name: name, value: %Surface.AST.Literal{value: value}},
         _caller
       )
       when is_list(value) do
    {name, to_string(value)}
  end

  defp eval_value(
         _component,
         %Surface.AST.Attribute{name: name, value: %Surface.AST.Literal{value: value}},
         _caller
       ) do
    {name, value}
  end

  defp eval_value(
         component,
         %Surface.AST.Attribute{
           name: name,
           value: %Surface.AST.AttributeExpr{
             original: value,
             value: expr,
             meta: %{line: line, file: file}
           }
         },
         caller
       ) do
    env = %Macro.Env{caller | line: line}
    prop_info = component.__get_prop__(name)

    {evaluated_value, _} =
      try do
        Code.eval_quoted(expr, [], env)
      rescue
        exception ->
          %exception_mod{} = exception

          message = """
          could not evaluate expression {{#{value}}}. Reason:

          (#{inspect(exception_mod)}) #{Exception.message(exception)}
          """

          error = %CompileError{line: line, file: file, description: message}
          reraise(error, __STACKTRACE__)
      end

    if valid_value?(prop_info.type, evaluated_value) do
      {prop_info.name, evaluated_value}
    else
      message = invalid_value_error(prop_info.name, prop_info.type, evaluated_value, value)
      IOHelper.compile_error(message, file, line)
    end
  end

  defp valid_value?(:string, value) when not is_binary(value) do
    false
  end

  defp valid_value?(:boolean, value) when not is_boolean(value) do
    false
  end

  defp valid_value?(:keyword, value) do
    Keyword.keyword?(value)
  end

  defp valid_value?(_, _value) do
    true
  end

  defp invalid_value_error(prop_name, prop_type, value, expr) do
    """
    invalid value for property "#{prop_name}"

    Expected a #{prop_type} while evaluating {{ #{String.trim(expr)} }}, got: #{inspect(value)}

    Hint: properties of macro components can only accept static values like module attributes,
    literals or compile-time expressions. Runtime variables and expressions, including component
    assigns, cannot be avaluated as they are not available during compilation.
    """
  end
end
