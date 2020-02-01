defmodule Surface.API do
  @moduledoc false

  @types [:any, :boolean, :list, :event, :string, :date, :datetime, :number, :integer,
          :decimal, :map, :fun]

  defmacro __using__([include: include]) do
    functions = for func <- include, arity <- [2, 3], into: [], do: {func, arity}

    quote do
      import unquote(__MODULE__), only: unquote(functions)
      @before_compile unquote(__MODULE__)

      for func <- unquote(include) do
        Module.register_attribute(__MODULE__, func, accumulate: true)
      end
    end
  end

  defmacro data(name_ast, type, opts \\ []) do
    validate(:data, name_ast, type, opts, __CALLER__)
    data_ast(name_ast, type, opts)
  end

  defp data_ast(name_ast, type, opts) do
    {name, _, _} = name_ast
    default = Keyword.get(opts, :default)

    quote do
      # TODO: Validate opts based on the type
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

  defp validate_name(_func, {name, meta, nil}) when is_atom(name) and is_list(meta) do
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
    valid_opts = valid_type_opts(type)

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

  defp valid_type_opts(_type) do
    [:default, :values]
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
    "Expected any of #{inspect(valid_opts)}. Got: #{inspect(unknown_items)}"
  end

  defmacro __before_compile__(env) do
    data = Module.get_attribute(env.module, :data)

    quote do
      def __data__() do
        unquote(Macro.escape(data))
      end
    end
  end
end
