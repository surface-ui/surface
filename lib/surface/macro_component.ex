defmodule Surface.MacroComponent do
  @moduledoc """
  A low-level component which is responsible for translating its own
  content at compile time.
  """

  alias Surface.Translator.IOHelper

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent, translator: __MODULE__
      use Surface.API, include: [:property, :slot]

      @behaviour Surface.Translator
    end
  end

  @doc """
  Tranlates the content of the macro component.
  """
  @callback translate(code :: any, caller: Macro.Env.t()) ::
              {open :: iodata(), content :: iodata(), close :: iodata()}

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

  @doc "Retrieve a component's config based on the `key`"
  def get_config(component, key, default \\ nil) do
    config = Application.get_env(:surface, :components, [])
    config[component][key] || default
  end

  @doc false
  def identity(value), do: value

  defp eval_value(component, {name, {:attribute_expr, [expr], %{line: line}}, _meta}, caller) do
    env = %Macro.Env{caller | line: caller.line + line}
    prop_info = component.__get_prop__(String.to_atom(name))

    {evaluated_value, _} =
      try do
        Code.eval_string("Surface.MacroComponent.identity(#{expr})", [], env)
      rescue
        exception ->
          prefix =
            case exception do
              %exception_mod{} ->
                "(#{inspect(exception_mod)}) "

              _ ->
                ""
            end

          message = """
          could not evaluate expression {{ #{expr} }}. Reason:

          #{prefix}#{Exception.message(exception)}
          """

          error = %CompileError{line: caller.line + line, file: caller.file, description: message}
          reraise(error, __STACKTRACE__)
      end

    if valid_value?(prop_info.type, evaluated_value) do
      {prop_info.name, evaluated_value}
    else
      message = invalid_value_error(prop_info.name, prop_info.type, evaluated_value, expr)
      IOHelper.compile_error(message, caller.file, caller.line + line)
    end
  end

  defp eval_value(_component, {name, value, _meta}, _caller) when is_list(value) do
    {String.to_atom(name), to_string(value)}
  end

  defp eval_value(_component, {name, value, _meta}, _caller) do
    {String.to_atom(name), value}
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
