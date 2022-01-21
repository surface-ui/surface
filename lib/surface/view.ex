defmodule Surface.View do
  @moduledoc """
  Use this module on regular Phoenix views to enable .sface templates

  ## Examples

  To make sface templates available on all your views, add to the `view` function on `lib/your_app_web.ex`:

      defmodule YourAppWeb do
        # ...

        def view do
          use Phoenix.View,
            root: "lib/your_app_web/templates",
            namespace: YourAppWeb
            
          # ...
          
          use Surface.View, root: "lib/your_app_web/templates"
        end
      end

  If you want to make it available only on specific views, you can add a new function on the `lib/your_app_web.ex`:

      defmodule YourAppWeb do
        # ...

        def surface_view(options \\ []) do
          [
            view(options),
            quote do
              use Surface.View, root: "lib/your_app_web/templates"
            end
          ]
        end
      end

  Then, replace `use YourAppWeb, :view` with `use YourAppWeb, :surface_view` on the views you want to enable sface
  templates.
  """

  defmacro __using__(opts \\ []) do
    %{module: module} = __CALLER__

    root = opts[:root] || raise(ArgumentError, "expected :root to be given as an option")

    renders =
      for {name, _} <- templates(module, root) do
        quote do
          def render("#{unquote(name)}.html", assigns) do
            __render_surface__(unquote(name), assigns)
          end
        end
      end

    before_compile =
      quote do
        @surface_view_root unquote(root)
        @before_compile unquote(__MODULE__)
      end

    [before_compile | renders]
  end

  defmacro __before_compile__(env) do
    root = Module.get_attribute(env.module, :surface_view_root)

    render_funs =
      for {name, path} <- templates(env.module, root) do
        ast =
          path
          |> File.read!()
          |> Surface.Compiler.compile(1, env, path)
          |> Surface.Compiler.to_live_struct()

        quote do
          @file unquote(path)
          @external_resource unquote(path)
          defp __render_surface__(unquote(name), var!(assigns)) do
            unquote(ast)
          end
        end
      end

    mix_recompile =
      quote do
        # Override definition injected by Phoenix.Template
        defoverridable __mix_recompile__?: 0

        @doc false
        def __mix_recompile__? do
          super() || __surface_recompile__?()
        end

        @doc false
        def __surface_recompile__? do
          unquote(hash(env.module, root)) != Surface.View.hash(unquote(env.module), unquote(root))
        end
      end

    [mix_recompile | render_funs]
  end

  defp templates(module, root) do
    module
    |> templates_wildcard(root)
    |> Path.wildcard()
    |> Enum.map(&{template_name(&1), &1})
  end

  defp templates_wildcard(module, root) do
    view_name =
      module
      |> Module.split()
      |> Enum.drop(1)
      |> Enum.map(&Macro.underscore/1)
      |> Enum.join("/")
      |> String.replace_trailing("_view", "")

    "#{root}/#{view_name}/*.sface"
  end

  defp template_name(path) do
    path
    |> Path.basename()
    |> String.replace_trailing(".sface", "")
  end

  @doc """
  Returns the hash of all template paths for the given view.
  Used by Surface to check if a given view requires recompilation when a new template is added.
  """
  def hash(module, root) do
    module
    |> templates_wildcard(root)
    |> Path.wildcard()
    |> Enum.sort()
    |> :erlang.md5()
  end
end
