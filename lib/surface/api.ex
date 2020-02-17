defmodule Surface.API do
  @moduledoc false

  @types [:any, :css_class, :list, :event, :children, :boolean, :string, :date,
          :datetime, :number, :integer, :decimal, :map, :fun, :atom, :module,
          :changeset, :form]

  @private_opts [:action]

  defmacro __using__([include: include]) do
    arities = %{
      property: [2, 3],
      data: [2, 3],
      context: [2, 3, 4]
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

  @doc "Defines a property for the component"
  defmacro property(name_ast, type, opts \\ []) do
    validate(:property, name_ast, type, opts, __CALLER__)
    property_ast(name_ast, type, opts)
  end

  @doc "Defines a data assign for the component"
  defmacro data(name_ast, type, opts \\ []) do
    validate(:data, name_ast, type, opts, __CALLER__)
    data_ast(name_ast, type, opts)
  end

  @doc false
  defmacro context(:set, name_ast) do
    opts = [{:action, :set}]
    validate(:context, name_ast, nil, opts, __CALLER__)
  end

  @doc false
  defmacro context(:get, name_ast) do
    opts = [action: :get]
    validate(:context, name_ast, :any, opts, __CALLER__)
    context_ast(name_ast, :any, opts, __CALLER__)
  end

  @doc "Sets or retrieves a context assign"
  defmacro context(:get, name_ast, opts) when is_list(opts) do
    opts = [{:action, :get} | opts]
    validate(:context, name_ast, :any, opts, __CALLER__)
    context_ast(name_ast, :any, opts, __CALLER__)
  end

  defmacro context(:set, name_ast, opts) when is_list(opts) do
    opts = [action: :set]
    validate(:context, name_ast, nil, opts, __CALLER__)
  end

  @doc """
  Same as `context/3` but specifying the assign's type
  as third argument. Only valid for action `:set`.
  """
  defmacro context(action, name_ast, type, opts \\ [])

  defmacro context(:set, name_ast, type, opts) do
    opts = [{:action, :set} | opts]
    validate(:context, name_ast, type, opts, __CALLER__)
    context_ast(name_ast, type, opts, __CALLER__)
  end

  defmacro context(:get, _name_ast, _type, _opts) do
    message = "cannot define the type of the assign when using action :get. " <>
              "The type should be already defined by a parent component using action :set"
    raise %CompileError{line: __CALLER__.line, file: __CALLER__.file, description: message}
  end

  defmacro context(action, _name_ast, _type, _opts) do
    message = "invalid context action. Expected :get or :set, got: #{inspect(action)}"
    raise %CompileError{line: __CALLER__.line, file: __CALLER__.file, description: message}
  end

  defp quoted_data_funcs(env) do
    data = Module.get_attribute(env.module, :data, [])

    quote do
      @doc false
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
      @doc false
      def __props__() do
        unquote(Macro.escape(props))
      end

      @doc false
      def __validate_prop__(prop) do
        prop in unquote(props_names)
      end

      @doc false
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
      @doc false
      def __context_gets__() do
        unquote(Macro.escape(gets))
      end

      @doc false
      def __context_sets__() do
        unquote(Macro.escape(sets))
      end

      @doc false
      def __context_sets_in_scope__() do
        unquote(Macro.escape(sets_in_scope))
      end

      @doc false
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
    # we don't accept custom :to for now
    to = caller.module

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
    {evaluated_opts, _} = Code.eval_quoted(opts, [], caller)
    with {:ok, name} <- validate_name(func, name_ast),
         :ok <- validate_type(func, name, type),
         :ok <- validate_opts(func, name, type, evaluated_opts),
         :ok <- validate_required_opts(func, type, evaluated_opts) do
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

  defp validate_type(_func, _name, nil) do
    {:error, "action :set requires the type of the assign as third argument"}
  end

  defp validate_type(_func, _name, type) when type in @types do
    :ok
  end

  defp validate_type(func, name, type) do
    message = "invalid type #{Macro.to_string(type)} for #{func} #{name}. Expected one " <>
              "of #{inspect(@types)}. Use :any if the type is not listed"
    {:error, message}
  end

  defp validate_required_opts(func, type, opts) do
    case get_required_opts(func, type, opts) -- Keyword.keys(opts) do
      [] ->
        :ok
      missing_opts ->
        {:error, "the following options are required: #{inspect(missing_opts)}"}
    end
  end

  defp validate_opts(func, name, type, opts) do
    valid_opts = get_valid_opts(func, type, opts)

    with true <- Keyword.keyword?(opts),
         keys <- Keyword.keys(opts),
         [] <- keys -- valid_opts ++ @private_opts do
      Enum.reduce_while(keys, :ok, fn key, _ ->
        case validate_opt(func, type, key, opts[key]) do
          :ok ->
            {:cont, :ok}
          error ->
            {:halt, error}
        end
      end)
    else
      false ->
        opts_str = Macro.to_string(opts)
        {:error, "invalid options for #{func} #{name}. Expected a keyword list of options, got: #{opts_str}"}
      unknown_options ->
        {:error, unknown_options_message(valid_opts, unknown_options)}
    end
  end

  defp get_valid_opts(:property, :list, _opts) do
    [:required, :default, :binding]
  end

  defp get_valid_opts(:property, :children, _opts) do
    [:required, :group, :use_bindings]
  end

  defp get_valid_opts(:property, _type, _opts) do
    [:required, :default, :values]
  end

  defp get_valid_opts(:data, _type, _opts) do
    [:default, :values]
  end

  defp get_valid_opts(:context, _type, opts) do
    case Keyword.fetch!(opts, :action) do
      :get ->
        [:from, :as]
      :set ->
        [:scope]
    end
  end

  defp get_required_opts(:context, _type, opts) do
    case Keyword.fetch!(opts, :action) do
      :get ->
        [:from]
      _ ->
        []
    end
  end

  defp get_required_opts(_func, _type, _opts) do
    []
  end

  defp validate_opt(:context, _type, :from, value) do
    if is_atom(value) && Code.ensure_compiled?(value) do
      :ok
    else
      {:error, "invalid value for option :from. Expected an existing module, got: #{inspect(value)}"}
    end
  end

  defp validate_opt(:context, _type, :as, value) when not is_atom(value) do
    {:error, "invalid value for option :as. Expected an atom, got: #{inspect(value)}"}
  end

  defp validate_opt(_func, _type, _opts, _key) do
    :ok
  end

  defp unknown_options_message(valid_opts, unknown_options) do
    {plural, unknown_items} =
      case unknown_options do
        [option] ->
          {"", option}
        _ ->
          {"s", unknown_options}
      end

    "unknown option#{plural} #{inspect(unknown_items)}. " <>
    "Available options: #{inspect(valid_opts)}"
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
