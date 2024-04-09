defmodule Surface.Renderer do
  @moduledoc false

  defmacro __before_compile__(env) do
    render? = Module.defines?(env.module, {:render, 1})
    slotable? = Module.defines?(env.module, {:__slot_name__, 0})
    root = Path.dirname(env.file)
    filename = template_filename(env)
    template = Path.join(root, filename)

    template_ast =
      if File.exists?(template) do
        env =
          env
          |> Map.put(:function, {:render, 1})
          |> Map.put(:file, template)

        template
        |> File.read!()
        |> Surface.Compiler.compile(1, env, template)
        |> Surface.Compiler.to_live_struct(
          caller: env,
          annotate_content:
            Code.ensure_loaded?(Phoenix.LiveView.HTMLEngine) &&
              function_exported?(Phoenix.LiveView.HTMLEngine, :annotate_body, 1) &&
              (&Phoenix.LiveView.HTMLEngine.annotate_body/1)
        )
      else
        nil
      end

    case {render?, slotable?, File.exists?(template)} do
      {true, _, true} ->
        quote do
          @doc """
          Renders the colocated .sface file with the given `assigns`

          Use this function when you need to override assigns for colocated
          templates.

          ## Example

              def render(assigns) do
                assigns = assign(assigns, value: "123")
                render_sface(assigns)
              end

          """
          @file unquote(template)
          @external_resource unquote(template)
          def render_sface(var!(assigns)) do
            unquote(template_ast)
          end
        end

      {true, _, false} ->
        :ok

      {false, _, true} ->
        quote do
          @file unquote(template)
          @external_resource unquote(template)
          def render(var!(assigns)) do
            unquote(template_ast)
          end

          def __template_file__(), do: unquote(template)
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
