defmodule Surface.Renderer do
  @moduledoc false

  defmacro __before_compile__(env) do
    render? = Module.defines?(env.module, {:render, 1})
    slotable? = Module.defines?(env.module, {:__slot_name__, 0})
    root = Path.dirname(env.file)
    filename = template_filename(env)
    template = Path.join(root, filename)

    case {render?, slotable?, File.exists?(template)} do
      {true, _, true} ->
        IO.warn(
          "ignoring template #{inspect(template)} because the component " <>
            "#{inspect(env.module)} defines a render/1 function",
          Macro.Env.stacktrace(env)
        )

        :ok

      {true, _, false} ->
        :ok

      {false, _, true} ->
        env = Map.put(env, :function, {:render, 1})

        ast =
          template
          |> File.read!()
          |> Surface.Compiler.compile(1, env, template)
          |> Surface.Compiler.to_live_struct()

        quote do
          @file unquote(template)
          @external_resource unquote(template)
          def render(var!(assigns)) do
            unquote(ast)
          end
        end

      {_, true, _} ->
        :ok

      _ ->
        message = ~s'''
        render/1 was not implemented for #{inspect(env.module)}.

        Make sure to either explicitly define a render/1 clause with a Surface template:

            def render(assigns) do
              ~F"""
              ...
              """
            end

        Or create a file at #{inspect(template)} with the Surface template.
        '''

        IO.warn(message, Macro.Env.stacktrace(env))

        quote do
          @external_resource unquote(template)
          def render(_assigns) do
            raise unquote(message)
          end
        end
    end
  end

  defp template_filename(env) do
    env.module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>(".sface")
  end
end
