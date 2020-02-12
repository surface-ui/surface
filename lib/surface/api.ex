defmodule Surface.API do
  @moduledoc false

  @types [:any, :css_class, :list, :event, :children, :boolean, :string, :date,
          :datetime, :number, :integer, :decimal, :map, :fun, :atom, :module,
          :changeset]

  defmacro __using__([include: include]) do
    arities = %{
      property: [2, 3],
      data: [2, 3],
      context: [3, 4]
    }

    functions = for func <- include, arity <- arities[func], into: [], do: {func, arity}

    quote do
      import unquote(__MODULE__), only: unquote(functions)
      @before_compile unquote(__MODULE__)

      for func <- unquote(include) do
        Module.register_attribute(__MODULE__, func, accumulate: true)
      end
    end
  end

  defmacro __before_compile__(env) do
    generate_docs(env)
    [
      quoted_property_funcs(env),
      quoted_data_funcs(env),
      quoted_context_funcs(env)
    ]
  end

  @doc "TODO"
  defmacro property(name_ast, type, opts \\ []) do
    validate(:property, name_ast, type, opts, __CALLER__)
    property_ast(name_ast, type, opts)
  end

  @doc "TODO"
  defmacro data(name_ast, type, opts \\ []) do
    validate(:data, name_ast, type, opts, __CALLER__)
    data_ast(name_ast, type, opts)
  end

  @doc "TODO"
  defmacro context(action, name_ast, opts) when is_list(opts) do
    opts = [{:action, action} | opts]
    validate(:context, name_ast, :any, opts, __CALLER__)
    context_ast(name_ast, :any, opts, __CALLER__)
  end

  defmacro context(action, name_ast, type, opts \\ []) do
    opts = [{:action, action} | opts]
    validate(:context, name_ast, type, opts, __CALLER__)
    context_ast(name_ast, type, opts, __CALLER__)
  end

  defp quoted_data_funcs(env) do
    data = Module.get_attribute(env.module, :data, [])

    quote do
      def __data__() do
        unquote(Macro.escape(data))
      end
    end
  end

  defp quoted_property_funcs(env) do
    props = Module.get_attribute(env.module, :property, [])
    props_names = Enum.map(props, fn prop -> prop.name end)
    props_by_name = for p <- props, into: %{}, do: {p.name, p}

    quote do
      def __props__() do
        unquote(Macro.escape(props))
      end

      def __validate_prop__(prop) do
        prop in unquote(props_names)
      end

      def __get_prop__(name) do
        Map.get(unquote(Macro.escape(props_by_name)), name)
      end
    end
  end

  defp quoted_context_funcs(env) do
    context = Module.get_attribute(env.module, :context, [])
    {gets, sets} = Enum.split_with(context, fn c -> c.opts[:action] == :get end)
    sets_in_scope = Enum.filter(sets, fn var -> var.opts[:scope] != :children end)
    assigns = gets ++ sets_in_scope

    quote do
      def __context_gets__() do
        unquote(Macro.escape(gets))
      end

      def __context_sets__() do
        unquote(Macro.escape(sets))
      end

      def __context_sets_in_scope__() do
        unquote(Macro.escape(sets_in_scope))
      end

      def __context_assigns__() do
        unquote(Macro.escape(assigns))
      end
    end
  end

  defp property_ast(name_ast, type, opts) do
    {name, _, _} = name_ast
    default = Keyword.get(opts, :default)
    required = Keyword.get(opts, :required, false)
    group = Keyword.get(opts, :group)
    binding = Keyword.get(opts, :binding)
    use_bindings = Keyword.get(opts, :use_bindings, [])

    quote do
      doc =
        case Module.get_attribute(__MODULE__, :doc) do
          {_, doc} -> doc
          _ -> nil
        end
      Module.delete_attribute(__MODULE__, :doc)

      @property %{
        name: unquote(name),
        type: unquote(type),
        doc: doc,
        opts: unquote(opts),
        opts_ast: unquote(Macro.escape(opts)),
        # TODO: Keep only :name, :type and :doc. The rest below should stay in :opts
        default: unquote(default),
        required: unquote(required),
        group: unquote(group),
        binding: unquote(binding),
        use_bindings: unquote(use_bindings)
      }
    end
  end

  defp data_ast(name_ast, type, opts) do
    {name, _, _} = name_ast
    default = Keyword.get(opts, :default)

    quote do
      @data %{
        name: unquote(name),
        type: unquote(type),
        doc: nil,
        opts: unquote(opts),
        opts_ast: unquote(Macro.escape(opts)),
        # TODO: Keep only :name and :type. The rest below should stay in :opts
        default: unquote(default)
      }
    end
  end

  defp context_ast(name_ast, type, opts, caller) do
    {name, _, _} = name_ast
    from = Keyword.get(opts, :from)
    to = Keyword.get(opts, :to, caller.module)

    quote do
      opts = unquote(opts)
      name = unquote(name)
      doc =
        if from = opts[:from] do
          from.__context_sets__()
          |> Enum.find(fn c -> c.name == name end)
          |> Map.get(:doc)
        else
          doc =
            case Module.get_attribute(__MODULE__, :doc) do
              {_, doc} -> doc
              _ -> nil
            end
          Module.delete_attribute(__MODULE__, :doc)
          doc
        end

      @context %{
        name: unquote(name),
        type: unquote(type),
        doc: doc,
        opts: unquote(opts),
        opts_ast: unquote(Macro.escape(opts)),
        # TODO: Keep only :name, :type and :doc. The rest below should stay in :opts
        from: unquote(from),
        to: unquote(to)
      }
    end
  end

  defp validate(func, name_ast, type, opts, caller) do
    with {:ok, name} <- validate_name(func, name_ast),
         :ok <- validate_type(func, name, type),
         :ok <- validate_opts(func, name, type, opts) do
      :ok
    else
      {:error, message} ->
        file = Path.relative_to_cwd(caller.file)
        raise %CompileError{line: caller.line, file: file, description: message}
    end
  end

  defp validate_name(_func, {name, meta, context})
    when is_atom(name) and is_list(meta) and is_atom(context) do
    {:ok, name}
  end

  defp validate_name(func, name_ast) do
    {:error, "invalid #{func} name. Expected a variable name, got: #{Macro.to_string(name_ast)}"}
  end

  defp validate_type(_func, _name, type) when type in @types do
    :ok
  end

  defp validate_type(func, name, type) do
    message = "invalid type #{Macro.to_string(type)} for #{func} #{name}. Expected one " <>
              "of #{inspect(@types)}. Use :any if the type is not listed"
    {:error, message}
  end

  defp validate_opts(func, name, type, opts) do
    valid_opts = valid_type_opts(func, type)

    with true <- is_list(opts) ,
         true <- Keyword.keyword?(opts),
         [] <- Keyword.keys(opts) -- valid_opts do
      :ok
    else
      false ->
        opts_str = Macro.to_string(opts)
        {:error, "invalid options for #{func} #{name}. Expected a keyword list of options, got: #{opts_str}"}
      unknown_options ->
        {:error, unknown_options_message(type, valid_opts, unknown_options)}
    end
  end

  defp valid_type_opts(:property, :list) do
    [:required, :default, :binding]
  end

  defp valid_type_opts(:property, :children) do
    [:required, :group, :use_bindings]
  end

  defp valid_type_opts(:property, _type) do
    [:required, :default, :values]
  end

  defp valid_type_opts(:data, _type) do
    [:default, :values]
  end

  defp valid_type_opts(:context, _type) do
    # TODO: Accept :required only if :action is :get
    # TODO: Validate if parent sets the context variable
    # TODO: If is :required, we could validate if there's a parent up in the tree
    [:from, :to, :as, :scope, :action, :required]
  end

  defp unknown_options_message(type, valid_opts, unknown_options) do
    {plural, unknown_items} =
      case unknown_options do
        [option] ->
          {"", option}
        _ ->
          {"s", unknown_options}
      end

    "unknown option#{plural} for type #{inspect(type)}. " <>
    "Expected any of #{inspect(valid_opts)}, got: #{inspect(unknown_items)}"
  end

  defp format_opts(opts_ast) do
    opts_ast
    |> Macro.to_string()
    |> String.slice(1..-2)
  end

  defp generate_docs(env) do
    props_doc = generate_props_docs(env.module)
    {line, doc} =
      case Module.get_attribute(env.module, :moduledoc) do
        nil ->
          {env.line, props_doc}
        {line, doc} ->
          {line, doc <> "\n" <> props_doc}
      end
    Module.put_attribute(env.module, :moduledoc, {line, doc})
  end

  defp generate_props_docs(module) do
    docs =
      for prop <- Module.get_attribute(module, :property) do
        doc = if prop.doc, do: " - #{prop.doc}.", else: ""
        opts = if prop.opts == [], do: "", else: ", #{format_opts(prop.opts_ast)}"
        "* **#{prop.name}** *#{inspect(prop.type)}#{opts}*#{doc}"
      end
      |> Enum.reverse()
      |> Enum.join("\n")

    """
    ### Properties

    #{docs}
    """
  end

end
