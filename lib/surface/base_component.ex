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

  # We're keeping this here to make the migration easier it will be removed when we remove
  # scope-aware context.
  @default_propagate_context_to_slots_map %{
    {Surface.Components.Form, :render} => true,
    {Surface.Components.Form.Field, :render} => true,
    {Surface.Components.Form.FieldContext, :render} => true,
    {Surface.Components.Form.Inputs, :render} => true
  }

  defmacro __using__(opts) do
    type = Keyword.fetch!(opts, :type)

    root = Path.dirname(__CALLER__.file)
    css_file_name = css_filename(__CALLER__)
    css_file = Path.join(root, css_file_name)

    Module.register_attribute(__CALLER__.module, :__style__, accumulate: true)

    if File.exists?(css_file) do
      style =
        css_file
        |> File.read!()
        |> Surface.Compiler.CSSTranslator.translate!(
          file: css_file,
          line: 1,
          scope: __CALLER__.module
        )

      Module.put_attribute(__CALLER__.module, :__style__, {:__module__, style})
    end

    quote do
      import Surface
      @behaviour unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :__components_calls__, accumulate: true)
      Module.register_attribute(__MODULE__, :__compile_time_deps__, accumulate: true)

      @before_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :component_type, persist: true)
      Module.put_attribute(__MODULE__, :component_type, unquote(type))

      @doc false
      def component_type do
        unquote(type)
      end

      @external_resource unquote(css_file)

      @propagate_context_to_slots_map unquote(__MODULE__).build_propagate_context_to_slots_map()
    end
  end

  @doc false
  def build_propagate_context_to_slots_map() do
    components_config = Application.get_env(:surface, :components, [])

    Enum.reduce(components_config, @default_propagate_context_to_slots_map, fn entry, acc ->
      {component, opts} =
        case entry do
          {mod, fun, opts} ->
            {{mod, fun}, opts}

          {mod, opts} ->
            {{mod, :render}, opts}
        end

      case Keyword.get(opts, :propagate_context_to_slots) do
        nil ->
          acc

        propagate_context_to_slots ->
          Map.put(acc, component, propagate_context_to_slots)
      end
    end)
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

    {imports, requires} =
      for %{component: mod, file: file, line: line, dep_type: dep_type} <- components,
          mod != env.module,
          reduce: {[], []} do
        {imports, requires} ->
          case dep_type do
            :export ->
              {[
                 quote line: line do
                   import unquote(mod), warn: false
                 end
                 | imports
               ], requires}

            :compile ->
              # We use `require` for macros or when there's an error loading the
              # module. This way if the missing/failing module is created/fixed,
              # Elixir will recompile this file.
              # NOTE: there's a bug in Elixir that report the error with the wrong line
              # in versions <= 1.17. See https://github.com/elixir-lang/elixir/issues/13542
              # for details.
              {imports,
               [
                 quote file: file, line: line do
                   require(unquote(mod)).__info__(:module)
                 end
                 | requires
               ]}
          end
      end

    imports_block =
      quote do
        if true do
          unquote(imports)
        end
      end

    sig_func = signature_func(env.module)

    component_signature =
      quote do
        @doc false
        def unquote(sig_func)(), do: nil

        @doc false
        def __surface_sig__(), do: unquote(sig_func)
      end

    [
      requires,
      component_signature,
      imports_block,
      def_components_calls_ast,
      style_ast
    ]
  end

  defp signature_func(mod) do
    # The component type changes the signature
    component_type = Module.get_attribute(mod, :component_type)
    entries = [{:component_type, component_type}]

    # The list of props changes the signature
    entries = Surface.API.get_props(mod) |> Enum.reduce(entries, &[prop_signature_entry(&1) | &2])

    # The list of slots changes the signature
    entries = Surface.API.get_slots(mod) |> Enum.reduce(entries, &[slot_signature_entry(&1) | &2])

    # The slot_name (slotable components) changes the signature
    entries =
      case Module.get_attribute(mod, :__slot_name__) do
        nil -> entries
        slot_name -> [{:slot_name, slot_name} | entries]
      end

    String.to_atom("__surface_sig_#{generate_signature(entries)}__")
  end

  defp prop_signature_entry(prop) do
    {prop.func, prop.name, prop.opts, prop.type}
  end

  defp slot_signature_entry(slot) do
    {slot.func, slot.name, slot.opts, slot.type}
  end

  defp generate_signature(entries) do
    entries
    |> Enum.sort()
    |> :erlang.term_to_binary()
    |> hash()
    |> Base.encode16(case: :lower)
    |> String.slice(0..6)
  end

  defp hash(bin) do
    :crypto.hash(:md5, bin)
  end

  defmacro __before_compile_init_slots__(env) do
    quoted_assigns =
      for %{name: name} <- Surface.API.get_slots(env.module) do
        quote do
          var!(assigns) = assign_new(var!(assigns), unquote(name), fn -> nil end)
        end
      end

    quoted_assigns = {:__block__, [], quoted_assigns}

    if Module.defines?(env.module, {:render, 1}) do
      quote do
        defoverridable render: 1

        def render(var!(assigns)) do
          unquote(quoted_assigns)

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
