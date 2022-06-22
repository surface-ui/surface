defmodule Surface.BaseComponent do
  @moduledoc false

  @doc """
  Declares which type of component this is. This is used to determine what
  validation should be applied at compile time for a module, as well as
  the rendering behaviour when this component is referenced.
  """
  @callback component_type() :: module()

  @doc """
  This function will be invoked with parsed AST node as the only argument. The result
  will replace the original node in the AST.

  This callback is invoked before directives are handled for this node, but after all
  children of this node have been fully processed.
  """
  @callback transform(node :: Surface.AST.t()) :: Surface.AST.t()

  @optional_callbacks transform: 1

  defmacro __using__(opts) do
    type = Keyword.fetch!(opts, :type)

    root = Path.dirname(__CALLER__.file)
    css_file_name = css_filename(__CALLER__)
    css_file = Path.join(root, css_file_name)

    style =
      if File.exists?(css_file) do
        css_file
        |> File.read!()
        |> Surface.Compiler.CSSTranslator.translate!(module: __CALLER__.module, file: css_file)
      end

    Module.put_attribute(__CALLER__.module, :__style__, style)

    quote do
      import Surface
      @behaviour unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :__components_calls__, accumulate: true)
      Module.register_attribute(__MODULE__, :__compile_time_deps__, accumulate: true)

      @before_compile unquote(__MODULE__)

      # TODO: Remove the alias after fix ElixirSense
      alias Module, as: Mod
      Mod.register_attribute(__MODULE__, :component_type, persist: true)
      Mod.put_attribute(__MODULE__, :component_type, unquote(type))

      @doc false
      def component_type do
        unquote(type)
      end

      @external_resource unquote(css_file)
    end
  end

  @doc false
  def restore_private_assigns(socket, %{__context__: context}) do
    socket
    |> Phoenix.LiveView.assign(:__context__, context)
  end

  def restore_private_assigns(socket, _assigns) do
    socket
  end

  defmacro __before_compile__(env) do
    components_calls = Module.get_attribute(env.module, :__components_calls__)
    style = Module.get_attribute(env.module, :__style__)

    style_ast =
      if style do
        quote do
          @doc false
          def __style__() do
            unquote(Macro.escape(style))
          end
        end
      end

    def_components_calls_ast =
      if components_calls != [] do
        quote do
          def __components_calls__() do
            unquote(Macro.escape(components_calls))
          end
        end
      end

    components = Enum.uniq_by(components_calls, & &1.component)

    requires =
      for %{component: mod, line: line} <- components, mod != env.module do
        quote line: line do
          require(unquote(mod)).__info__(:module)
        end
      end

    [
      requires,
      def_components_calls_ast,
      style_ast
    ]
  end

  defmacro __before_compile_init_slots__(env) do
    quoted_assigns =
      for %{name: name} <- Surface.API.get_slots(env.module) do
        quote do
          var!(assigns) = assign_new(var!(assigns), unquote(name), fn -> nil end)
        end
      end

    if Module.defines?(env.module, {:render, 1}) do
      quote do
        defoverridable render: 1

        def render(var!(assigns)) do
          unquote_splicing(quoted_assigns)

          super(var!(assigns))
        end
      end
    end
  end

  defp css_filename(env) do
    env.module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>(".css")
  end
end
