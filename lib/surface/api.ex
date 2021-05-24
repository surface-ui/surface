defmodule Surface.API do
  @moduledoc false

  alias Surface.IOHelper

  @types [
    :any,
    :css_class,
    :list,
    :event,
    :boolean,
    :string,
    :time,
    :date,
    :datetime,
    :naive_datetime,
    :number,
    :integer,
    :decimal,
    :map,
    :fun,
    :atom,
    :module,
    :changeset,
    :form,
    :keyword,
    :struct,
    :tuple,
    :pid,
    :port,
    :reference,
    :bitstring,
    :range,
    :mapset,
    :regex,
    :uri,
    :path,
    # Private
    :generator,
    :context_put,
    :context_get
  ]

  defmacro __using__(include: include) do
    arities = %{
      prop: [2, 3],
      slot: [1, 2],
      data: [2, 3]
    }

    functions = for func <- include, arity <- arities[func], into: [], do: {func, arity}

    quote do
      import unquote(__MODULE__), only: unquote(functions)
      @before_compile unquote(__MODULE__)
      @after_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :assigns, accumulate: true)
      # Any caller component can hold other components with slots
      Module.register_attribute(__MODULE__, :assigned_slots_by_parent, accumulate: false)

      Module.put_attribute(__MODULE__, :use_context?, false)

      for func <- unquote(include) do
        Module.register_attribute(__MODULE__, func, accumulate: true)
      end
    end
  end

  defmacro __before_compile__(env) do
    generate_docs(env)

    [
      quoted_prop_funcs(env),
      quoted_slot_funcs(env),
      quoted_data_funcs(env),
      quoted_context_funcs(env)
    ]
  end

  def __after_compile__(env, _) do
    validate_assigns!(env)
    validate_duplicated_assigns!(env)
    validate_slot_props_bindings!(env)
    validate_duplicate_root_props!(env)
  end

  @doc "Defines a property for the component"
  defmacro prop(name_ast, type_ast, opts_ast \\ []) do
    build_assign_ast(:prop, name_ast, type_ast, opts_ast, __CALLER__)
  end

  @doc "Defines a slot for the component"
  defmacro slot(name_ast, opts_ast \\ []) do
    build_assign_ast(:slot, name_ast, :any, opts_ast, __CALLER__)
  end

  @doc "Defines a data assign for the component"
  defmacro data(name_ast, type_ast, opts_ast \\ []) do
    build_assign_ast(:data, name_ast, type_ast, opts_ast, __CALLER__)
  end

  @doc false
  def get_assigns(module) do
    Module.get_attribute(module, :assigns, [])
  end

  @doc false
  def get_slots(module) do
    Module.get_attribute(module, :slot, [])
  end

  @doc false
  def get_props(module) do
    Module.get_attribute(module, :prop, [])
  end

  @doc false
  def get_data(module) do
    Module.get_attribute(module, :data, [])
  end

  @doc false
  def get_defaults(module) do
    for %{name: name, opts: opts} <- get_data(module), Keyword.has_key?(opts, :default) do
      {name, opts[:default]}
    end
  end

  @doc false
  def put_assign(caller, func, name, type, opts, opts_ast, line) do
    assign = %{
      func: func,
      name: name,
      type: type,
      doc: pop_doc(caller.module),
      opts: opts,
      opts_ast: opts_ast,
      line: line
    }

    Module.put_attribute(caller.module, :assigns, assign)
    Module.put_attribute(caller.module, assign.func, assign)
  end

  @doc false
  def sort_props(props) when is_list(props) do
    Enum.sort_by(props, &{&1.name != :id, !&1.opts[:required], &1.line})
  end

  defp validate_duplicated_assigns!(env) do
    env.module
    |> Module.get_attribute(:assigns, [])
    |> Enum.group_by(fn %{name: name, opts: opts} -> opts[:as] || name end)
    |> Enum.filter(fn {_, list} -> length(list) > 1 end)
    |> validate_duplicated_assigns!(env)
  end

  defp validate_duplicated_assigns!(assigns, env) do
    for assign <- assigns do
      validate_duplicated_assign!(assign, env)
    end
  end

  defp validate_duplicated_assign!({name, [assign, duplicated | _]}, env) do
    component_type = Module.get_attribute(env.module, :component_type)
    builtin_assign? = name in Surface.Compiler.Helpers.builtin_assigns_by_type(component_type)

    details = existing_assign_details_message(builtin_assign?, duplicated)
    message = ~s(cannot use name "#{name}". #{details}.)

    IOHelper.compile_error(message, env.file, assign.line)
  end

  defp validate_duplicate_root_props!(env) do
    props =
      env.module.__props__()
      |> Enum.filter(& &1.opts[:root])

    case props do
      [prop, _dupicated | _] ->
        message = """
        cannot define multiple properties as `root: true`. \
        Property `#{prop.name}` at line #{prop.line} was already defined as root.

        Hint: choose a single property to be the root prop.
        """

        IOHelper.compile_error(message, env.file, env.line)

      _ ->
        nil
    end
  end

  defp existing_assign_details_message(true = _builtin?, %{func: func}) do
    "There's already a built-in #{func} assign with the same name"
  end

  defp existing_assign_details_message(false = _builtin?, %{func: func, line: line})
       when func == :slot do
    """
    There's already a #{func} assign with the same name at line #{line}.
    You could use the optional ':as' option in slot macro to name the related assigns.
    """
  end

  defp existing_assign_details_message(false = _builtin?, %{func: func, line: line}) do
    "There's already a #{func} assign with the same name at line #{line}"
  end

  defp quoted_data_funcs(env) do
    data = get_data(env.module)

    quote do
      @doc false
      def __data__() do
        unquote(Macro.escape(data))
      end
    end
  end

  defp quoted_prop_funcs(env) do
    props =
      env.module
      |> get_props()
      |> sort_props()

    props_names = for p <- props, do: p.name
    props_by_name = for p <- props, into: %{}, do: {p.name, p}
    required_props_names = for %{name: name, opts: opts} <- props, opts[:required], do: name

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

      @doc false
      def __required_props_names__() do
        unquote(Macro.escape(required_props_names))
      end
    end
  end

  defp quoted_slot_funcs(env) do
    slots = env.module |> get_slots() |> Enum.uniq_by(& &1.name)
    slots_names = Enum.map(slots, fn slot -> slot.name end)
    slots_by_name = for p <- slots, into: %{}, do: {p.name, p}

    required_slots_names =
      for %{name: name, opts: opts} <- slots, opts[:required] do
        name
      end

    assigned_slots_by_parent = Module.get_attribute(env.module, :assigned_slots_by_parent) || %{}

    quote do
      @doc false
      def __slots__() do
        unquote(Macro.escape(slots))
      end

      @doc false
      def __validate_slot__(prop) do
        prop in unquote(slots_names)
      end

      @doc false
      def __get_slot__(name) do
        Map.get(unquote(Macro.escape(slots_by_name)), name)
      end

      @doc false
      def __assigned_slots_by_parent__() do
        unquote(Macro.escape(assigned_slots_by_parent))
      end

      @doc false
      def __required_slots_names__() do
        unquote(Macro.escape(required_slots_names))
      end
    end
  end

  defp quoted_context_funcs(env) do
    use_context? = Module.get_attribute(env.module, :use_context?)

    quote do
      @doc false
      def __use_context__?() do
        unquote(use_context?)
      end
    end
  end

  defp validate_assigns!(env) do
    assigns = Module.get_attribute(env.module, :assigns, [])

    for assign <- assigns do
      validate_assign!(assign, env)
    end
  end

  defp validate_assign!(%{func: func, name: name, type: type, opts: opts, line: line}, env) do
    with :ok <- validate_type(func, name, type),
         :ok <- validate_opts_keys(func, name, type, opts),
         :ok <- validate_opts(func, name, type, opts, line, env) do
      :ok
    else
      {:error, message} ->
        file = Path.relative_to_cwd(env.file)
        IOHelper.compile_error(message, file, line)
    end
  end

  defp validate_name_ast!(_func, {name, meta, context}, _caller)
       when is_atom(name) and is_list(meta) and is_atom(context) do
    name
  end

  defp validate_name_ast!(func, name_ast, caller) do
    message = """
    invalid #{func} name. Expected a variable name, got: #{Macro.to_string(name_ast)}\
    """

    IOHelper.compile_error(message, caller.file, caller.line)
  end

  defp validate_type_ast!(_func, _name, type, _caller) when is_atom(type) do
    type
  end

  defp validate_type_ast!(func, name, type_ast, caller) do
    message = """
    invalid type for #{func} #{name}. \
    Expected an atom, got: #{Macro.to_string(type_ast)}
    """

    IOHelper.compile_error(message, caller.file, caller.line)
  end

  defp validate_type(_func, _name, type) when type in @types do
    :ok
  end

  defp validate_type(func, name, type) do
    message = """
    invalid type #{Macro.to_string(type)} for #{func} #{name}.
    Expected one of #{inspect(@types)}.
    Hint: Use :any if the type is not listed.\
    """

    {:error, message}
  end

  defp validate_opts_keys(func, _name, type, opts) do
    with keys <- Keyword.keys(opts),
         valid_opts <- get_valid_opts(func, type, opts),
         [] <- keys -- valid_opts do
      :ok
    else
      unknown_options ->
        valid_opts = get_valid_opts(func, type, opts)
        {:error, unknown_options_message(valid_opts, unknown_options)}
    end
  end

  defp validate_opts_ast!(func, _name, opts, caller) when is_list(opts) do
    for {key, value} <- opts do
      {key, validate_opt_ast!(func, key, value, caller)}
    end
  end

  defp validate_opts_ast!(func, name, opts, caller) do
    message = """
    invalid options for #{func} #{name}. \
    Expected a keyword list of options, got: #{Macro.to_string(opts)}
    """

    IOHelper.compile_error(message, caller.file, caller.line)
  end

  defp validate_opts(func, name, type, opts, line, env) do
    Enum.reduce_while(opts, :ok, fn {key, value}, _acc ->
      case validate_opt(func, name, type, opts, key, value, line, env) do
        :ok ->
          {:cont, :ok}

        error ->
          {:halt, error}
      end
    end)
  end

  defp get_valid_opts(:prop, _type, _opts) do
    [:required, :default, :values, :values!, :accumulate, :root]
  end

  defp get_valid_opts(:data, _type, _opts) do
    [:default, :values, :values!]
  end

  defp get_valid_opts(:slot, _type, _opts) do
    [:required, :props, :as]
  end

  defp validate_opt_ast!(:slot, :props, args_ast, caller) do
    Enum.map(args_ast, fn
      {name, {:^, _, [{generator, _, context}]}} when context in [Elixir, nil] ->
        Macro.escape(%{name: name, generator: generator})

      name when is_atom(name) ->
        Macro.escape(%{name: name, generator: nil})

      ast ->
        message =
          "invalid slot prop #{Macro.to_string(ast)}. " <>
            "Expected an atom or a binding to a generator as `key: ^property_name`"

        IOHelper.compile_error(message, caller.file, caller.line)
    end)
  end

  defp validate_opt_ast!(_func, _key, value, _caller) do
    value
  end

  defp validate_opt(:prop, _name, _type, _opts, :root, value, _line, _env)
       when not is_boolean(value) do
    {:error, "invalid value for option :root. Expected a boolean, got: #{inspect(value)}"}
  end

  defp validate_opt(_func, _name, _type, _opts, :required, value, _line, _env)
       when not is_boolean(value) do
    {:error, "invalid value for option :required. Expected a boolean, got: #{inspect(value)}"}
  end

  defp validate_opt(:prop, name, _type, opts, :default, value, line, env) do
    if Keyword.get(opts, :required, false) do
      IOHelper.warn(
        "setting a default value on a required prop has no effect. Either set the default value or set the prop as required, but not both.",
        env,
        fn _ -> line end
      )
    end

    warn_on_invalid_default(:prop, name, value, opts, line, env)

    :ok
  end

  defp validate_opt(:data, name, _type, opts, :default, value, line, env) do
    warn_on_invalid_default(:data, name, value, opts, line, env)

    :ok
  end

  defp validate_opt(_func, _name, _type, _opts, :values, value, _line, _env)
       when not is_list(value) and not is_struct(value, Range) do
    {:error,
     "invalid value for option :values. Expected a list of values or a Range, got: #{
       inspect(value)
     }"}
  end

  defp validate_opt(:prop, _name, _type, _opts, :accumulate, value, _line, _env)
       when not is_boolean(value) do
    {:error, "invalid value for option :accumulate. Expected a boolean, got: #{inspect(value)}"}
  end

  defp validate_opt(:slot, _name, _type, _opts, :as, value, _line, _caller)
       when not is_atom(value) do
    {:error, "invalid value for option :as in slot. Expected an atom, got: #{inspect(value)}"}
  end

  defp validate_opt(:slot, :default, _type, _opts, :props, value, line, env) do
    if Module.defines?(env.module, {:__slot_name__, 0}) do
      slot_name = Module.get_attribute(env.module, :__slot_name__)

      prop_example =
        value
        |> Enum.map(fn %{name: name} -> "#{name}: #{name}" end)
        |> Enum.join(", ")

      component_name = Macro.to_string(env.module)

      message = """
      props for the default slot in a slotable component are not accessible - instead the props \
      from the parent's #{slot_name} slot will be exposed via `:let={{ ... }}`.

      Hint: You can remove these props, pull them up to the parent component, or make this component not slotable \
      and use it inside an explicit template element:
      ```
      <#template name="#{slot_name}">
        <#{component_name} :let={{ #{prop_example} }}>
          ...
        </#{component_name}>
      </#template>
      ```
      """

      IOHelper.warn(message, env, fn _ -> line end)
    end

    :ok
  end

  defp validate_opt(_func, _name, _type, _opts, _key, _value, _line, _env) do
    :ok
  end

  defp warn_on_invalid_default(type, name, default, opts, line, env) do
    accumulate? = Keyword.get(opts, :accumulate, false)
    values! = Keyword.get(opts, :values!)

    cond do
      accumulate? and not is_list(default) ->
        IOHelper.warn(
          "#{type} `#{name}` default value `#{inspect(default)}` must be a list when `accumulate: true`",
          env,
          fn _ -> line end
        )

      accumulate? and not is_nil(values!) and
          not MapSet.subset?(MapSet.new(default), MapSet.new(values!)) ->
        IOHelper.warn(
          """
          #{type} `#{name}` default value `#{inspect(default)}` does not exist in `:values!`

          Hint: Either choose an existing value or replace `:values!` with `:values` to skip validation.
          """,
          env,
          fn _ -> line end
        )

      not accumulate? and not is_nil(values!) and default not in values! ->
        IOHelper.warn(
          """
          #{type} `#{name}` default value `#{inspect(default)}` does not exist in `:values!`

          Hint: Either choose an existing value or replace `:values!` with `:values` to skip validation.
          """,
          env,
          fn _ -> line end
        )

      true ->
        :ok
    end
  end

  defp unknown_options_message(valid_opts, unknown_options) do
    {plural, unknown_items} =
      case unknown_options do
        [option] ->
          {"", option}

        _ ->
          {"s", unknown_options}
      end

    """
    unknown option#{plural} #{inspect(unknown_items)}. \
    Available options: #{inspect(valid_opts)}\
    """
  end

  defp format_opts(opts_ast) do
    opts_ast
    |> Macro.to_string()
    |> String.slice(1..-2)
  end

  defp generate_docs(env) do
    do_generate_docs(Module.get_attribute(env.module, :moduledoc), env)
  end

  defp do_generate_docs({_line, false}, _env), do: :ok
  defp do_generate_docs(nil, env), do: do_generate_docs({env.line, nil}, env)

  defp do_generate_docs({line, doc}, env) do
    docs =
      [
        doc,
        generate_props_docs(env.module),
        generate_slots_docs(env.module),
        generate_events_docs(env.module)
      ]
      |> Enum.filter(&(&1 != nil))
      |> Enum.join("\n")

    Module.put_attribute(
      env.module,
      :moduledoc,
      {line, docs}
    )
  end

  defp generate_props_docs(module) do
    # Events are special properties we treat in a separate doc section
    docs =
      for prop <- get_props(module), prop.type != :event do
        doc = if prop.doc, do: " - #{prop.doc}.", else: ""
        opts = if prop.opts == [], do: "", else: ", #{format_opts(prop.opts_ast)}"
        "* **#{prop.name}** *#{inspect(prop.type)}#{opts}*#{doc}"
      end
      |> Enum.reverse()
      |> Enum.join("\n")

    if docs != "" do
      """
      ## Properties

      #{docs}
      """
    end
  end

  defp generate_slots_docs(module) do
    docs =
      for slot <- get_slots(module) do
        doc = if slot.doc, do: " - #{slot.doc}.", else: ""
        opts = if slot.opts == [], do: "", else: ", #{format_opts(slot.opts_ast)}"
        "* **#{slot.name}#{opts}**#{doc}"
      end
      |> Enum.reverse()
      |> Enum.join("\n")

    if docs != "" do
      """
      ## Slots

      #{docs}
      """
    end
  end

  defp generate_events_docs(module) do
    docs =
      for prop <- get_props(module), prop.type == :event do
        doc = if prop.doc, do: " - #{prop.doc}.", else: ""
        opts = if prop.opts == [], do: "", else: ", #{format_opts(prop.opts_ast)}"
        "* **#{prop.name}#{opts}**#{doc}"
      end
      |> Enum.reverse()
      |> Enum.join("\n")

    if docs != "" do
      """
      ## Events

      #{docs}
      """
    end
  end

  defp validate_slot_props_bindings!(env) do
    for slot <- env.module.__slots__(),
        slot_props = Keyword.get(slot.opts, :props, []),
        %{name: name, generator: generator} <- slot_props,
        generator != nil do
      case env.module.__get_prop__(generator) do
        nil ->
          existing_properties_names = env.module.__props__() |> Enum.map(& &1.name)

          message = """
          cannot bind slot prop `#{name}` to property `#{generator}`. \
          Expected an existing property after `^`, \
          got: an undefined property `#{generator}`.

          Hint: Available properties are #{inspect(existing_properties_names)}\
          """

          IOHelper.compile_error(message, env.file, slot.line)

        %{type: type} when type != :list ->
          message = """
          cannot bind slot prop `#{name}` to property `#{generator}`. \
          Expected a property of type :list after `^`, \
          got: a property of type #{inspect(type)}\
          """

          IOHelper.compile_error(message, env.file, slot.line)

        _ ->
          :ok
      end
    end
  end

  defp pop_doc(module) do
    doc =
      case Module.get_attribute(module, :doc) do
        {_, doc} -> doc
        _ -> nil
      end

    Module.delete_attribute(module, :doc)
    doc
  end

  defp build_assign_ast(func, name_ast, type_ast, opts_ast, caller) do
    name = validate_name_ast!(func, name_ast, caller)
    opts = validate_opts_ast!(func, name, opts_ast, caller)
    type = validate_type_ast!(func, name, type_ast, caller)

    quote bind_quoted: [
            func: func,
            name: name,
            type: type,
            opts: opts,
            opts_ast: Macro.escape(opts_ast),
            line: caller.line
          ] do
      Surface.API.put_assign(__ENV__, func, name, type, opts, opts_ast, line)
    end
  end
end
