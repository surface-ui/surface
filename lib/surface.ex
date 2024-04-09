defmodule Surface do
  @moduledoc """
  Surface is a component based library for **Phoenix LiveView**.

  Built on top of the new `Phoenix.LiveComponent` API, Surface provides
  a more declarative way to express and use components in Phoenix.

  Full documentation and live examples can be found at [surface-ui.org](https://surface-ui.org)

  This module defines the `~F` sigil that should be used to translate Surface
  code into Phoenix templates.

  In order to have `~F` available for any Phoenix view, add the following import to your web
  file in `lib/my_app_web.ex`:

      # lib/my_app_web.ex

      ...

      def view do
        quote do
          ...
          import Surface
        end
      end

  Additionally, use `Surface.init/1` in your mount function to initialize assigns used internally by surface:

      # A LiveView using surface templates

      defmodule PageLive do
        use Phoenix.LiveView
        import Surface

        def mount(_params, _session, socket) do
          socket = Surface.init(socket)
          ...
          {:ok, socket}
        end

        def render(assigns) do
          ~F"\""
          ...
          "\""
        end
      end

      # A LiveComponent using surface templates

      defmodule NavComponent do
        use Phoenix.LiveComponent
        import Surface

        def mount(socket) do
          socket = Surface.init(socket)
          ...
          {:ok, socket}
        end

        def render(assigns) do
          ~F"\""
          ...
          "\""
        end
      end

  ## Defining components

  To create a component you need to define a module and `use` one of the available component types:

    * `Surface.Component` - A stateless component.
    * `Surface.LiveComponent` - A live stateful component.
    * `Surface.LiveView` - A wrapper component around `Phoenix.LiveView`.
    * `Surface.MacroComponent` - A low-level component which is responsible for translating its own content at compile time.

  ## Example

      # A functional stateless component

      defmodule Button do
        use Surface.Component

        prop click, :event
        prop kind, :string, default: "is-info"

        def render(assigns) do
          ~F"\""
          <button class={"button", @kind} :on-click={@click}>
            <#slot/>
          </button>
          "\""
        end
      end

  You can visit the documentation of each type of component for further explanation and examples.
  """

  alias Surface.API
  alias Surface.Compiler.Helpers
  alias Surface.IOHelper
  alias Surface.TypeHandler

  @doc """
  Translates Surface code into Phoenix templates.
  """
  defmacro sigil_F({:<<>>, meta, [string]}, opts) do
    line_offset = if Keyword.has_key?(meta, :indentation), do: 1, else: 0
    line = __CALLER__.line + line_offset
    indentation = meta[:indentation] || 0
    column = meta[:column] || 1

    component_type = Module.get_attribute(__CALLER__.module, :component_type)

    string
    |> Surface.Compiler.compile(line, __CALLER__, __CALLER__.file,
      checks: [no_undefined_assigns: component_type != nil],
      indentation: indentation,
      column: column
    )
    |> Surface.Compiler.to_live_struct(
      debug: Enum.member?(opts, ?d),
      file: __CALLER__.file,
      line: line,
      caller: __CALLER__,
      annotate_content: annotate_content()
    )
  end

  @doc """
  Embeds an `.sface` template as a function component.

  ## Example

      defmodule MyAppWeb.Layouts do
        use MyAppWeb, :html

        embed_sface "layouts/root.sface"
        embed_sface "layouts/app.sface"
      end

  The code above generates two functions, `root` and `app`. You can use both
  as regular function components or as layout templates.
  """
  defmacro embed_sface(relative_file) do
    file =
      __CALLER__.file
      |> Path.dirname()
      |> Path.join(relative_file)

    if File.exists?(file) do
      name = file |> Path.rootname() |> Path.basename()

      quote bind_quoted: [file: file, name: name] do
        @external_resource file
        @file file

        body = Surface.__compile_sface__(name, file, __ENV__)

        def unquote(String.to_atom(name))(var!(assigns)) do
          _ = var!(assigns)
          unquote(body)
        end
      end
    else
      message = """
      could not read template "#{relative_file}": no such file or directory. \
      Trying to read file "#{file}".
      """

      IOHelper.compile_error(message, __CALLER__.file, __CALLER__.line)
    end
  end

  @doc false
  def __compile_sface__(name, file, env) do
    file
    |> File.read!()
    |> Surface.Compiler.compile(1, env, file)
    |> Surface.Compiler.to_live_struct(
      caller: %Macro.Env{env | file: file, line: 1, function: {String.to_atom(name), 1}},
      annotate_content: annotate_content()
    )
  end

  @doc """
  Converts the given code into Surface's AST.

  The code must be passed with the `do` block using the `~F` sigil.

  Optional `line`, `file` and `caller` metadata can be passed using `opts`.

  ## Example

      iex> [tag] =
      ...>   quote_surface do
      ...>     ~F"<div>content</div>"
      ...>   end
      ...>
      ...> tag.children
      [%Surface.AST.Literal{directives: [], value: "content"}]

  """
  defmacro quote_surface(opts \\ [], do: block) do
    {code, sigil_meta, string_meta} =
      case block do
        {:sigil_F, sigil_meta, [{:<<>>, string_meta, [code]}, _]} ->
          {code, sigil_meta, string_meta}

        _ ->
          message = "the code to be quoted must be wrapped in a `~F` sigil."
          IOHelper.compile_error(message, __CALLER__.file, __CALLER__.line)
      end

    delimiter = Keyword.fetch!(sigil_meta, :delimiter)
    line_offset = if delimiter == ~S("""), do: 1, else: 0
    default_line = Keyword.get(sigil_meta, :line) + line_offset

    line = Keyword.get(opts, :line, default_line)
    file = Keyword.get(opts, :file, __CALLER__.file)
    caller = Keyword.get(opts, :caller, quote(do: __ENV__))
    indentation = Keyword.get(string_meta, :indentation, 0)

    quote do
      Surface.Compiler.compile(unquote(code), unquote(line), unquote(var!(caller)), unquote(file),
        checks: [no_undefined_assigns: false],
        indentation: unquote(indentation),
        column: 1,
        variables: binding()
      )
    end
  end

  @doc "Retrieve a component's config based on the `key`"
  def get_config(component, key) do
    config = get_components_config()
    config[component][key]
  end

  @doc "Retrieve the component's config based on the `key`"
  defmacro get_config(key) do
    component = __CALLER__.module

    quote do
      get_config(unquote(component), unquote(key))
    end
  end

  @doc "Retrieve all component's config"
  def get_components_config() do
    Application.get_env(:surface, :components, [])
  end

  @doc "Initialize surface state in the socket"
  def init(socket) do
    socket
    |> Phoenix.Component.assign_new(:__context__, fn -> %{} end)
  end

  @doc false
  def components(opts \\ []) do
    only_current_project = Keyword.get(opts, :only_current_project, false)
    project_app = Mix.Project.config()[:app]

    apps =
      if only_current_project do
        [project_app]
      else
        :ok = Application.ensure_loaded(project_app)
        project_deps_apps = Application.spec(project_app, :applications) || []
        [project_app | project_deps_apps]
      end

    for app <- apps,
        deps_apps = Application.spec(app)[:applications] || [],
        app in [:surface, project_app] or :surface in deps_apps,
        {dir, files} = app_beams_dir_and_files(app),
        file <- files,
        List.starts_with?(file, ~c"Elixir.") do
      :filename.join(dir, file)
    end
    |> Enum.chunk_every(50)
    |> Task.async_stream(fn files ->
      for file <- files,
          {:ok, {_, [{_, chunk} | _]}} = :beam_lib.chunks(file, [~c"Attr"]),
          chunk |> :erlang.binary_to_term() |> Keyword.get(:component_type) do
        file |> Path.basename(".beam") |> String.to_atom()
      end
    end)
    |> Enum.flat_map(fn {:ok, result} -> result end)
  end

  defp app_beams_dir_and_files(app) do
    dir =
      app
      |> Application.app_dir()
      |> Path.join("ebin")
      |> String.to_charlist()

    {:ok, files} = :file.list_dir(dir)
    {dir, files}
  end

  @doc false
  def default_props(module) do
    # The function_exported? call returns false if the module hasn't been loaded yet. Calling
    # module.__info__(:module) forces the module to be loaded and it turned out to be cheaper
    # then Code.ensure_loaded/1, so we use it instead to guarantee we get the props.
    props =
      if function_exported?(module, :__props__, 0) or
           (module && function_exported?(module.__info__(:module), :__props__, 0)) do
        module.__props__()
      else
        []
      end

    Enum.map(props, fn %{name: name, opts: opts} -> {name, opts[:default]} end)
  end

  @doc false
  def build_dynamic_assigns(context, static_props, dynamic_props, module, node_alias, ctx) do
    static_props =
      for {name, value} <- static_props || [] do
        {clauses, opts, original} =
          case value do
            # Value is an expression
            {_clauses, _opts, _original} ->
              value

            # Value is a literal
            _ ->
              {[value], [], nil}
          end

        {name, TypeHandler.runtime_prop_value!(module, name, clauses, opts, inspect(module), original, ctx)}
      end

    build_assigns(context, static_props, dynamic_props, module, node_alias, ctx)
  end

  @doc false
  def build_assigns(context, static_props, dynamic_props, module, node_alias, ctx) do
    static_prop_names = Keyword.keys(static_props) |> Enum.uniq()
    only_dynamic_props = Enum.reject(dynamic_props, &Enum.member?(static_prop_names, elem(&1, 0)))

    props =
      module
      |> default_props()
      |> Keyword.merge(runtime_props!(static_props, module, node_alias, ctx))
      |> Keyword.merge(runtime_props!(only_dynamic_props, module, node_alias, ctx))

    if module do
      Map.new([__context__: context] ++ props)
    else
      # Function components don't support contexts
      Map.new(props)
    end
  end

  @doc false
  def css_class(value) when is_list(value) do
    with {:ok, value} <- Surface.TypeHandler.CssClass.expr_to_value(value, [], _ctx = %{}),
         {:ok, string} <- Surface.TypeHandler.CssClass.value_to_html("class", value) do
      string
    else
      _ ->
        Surface.IOHelper.runtime_error(
          "invalid value. " <>
            "Expected a :css_class, got: #{inspect(value)}"
        )
    end
  end

  def event_to_opts(nil, _event_name) do
    []
  end

  def event_to_opts(value, event_name) do
    [{event_name, Surface.TypeHandler.Event.normalize_value(value)}]
  end

  @doc false
  defmacro prop_to_attr_opts(prop_value, prop_name) do
    quote do
      prop_to_attr_opts(unquote(prop_value), unquote(prop_name), __ENV__)
    end
  end

  @doc false
  def prop_to_attr_opts(nil, _prop_name, _caller) do
    []
  end

  def prop_to_attr_opts(prop_value, prop_name, caller) do
    module = caller.module
    meta = %{caller: caller, line: caller.line, node_alias: module}
    {type, _opts} = Surface.TypeHandler.attribute_type_and_opts(module, prop_name, meta)
    Surface.TypeHandler.attr_to_opts!(type, prop_name, prop_value)
  end

  @doc """
  Tests if a slot has been filled in.

  Useful to avoid rendering unnecessary html tags that are used to wrap an optional slot
  in combination with `:if` directive.

  ## Examples

    ```
    <div :if={slot_assigned?(:header)}>
      <#slot {@header}/>
    </div>
    ```
  """
  defmacro slot_assigned?(slot) when is_atom(slot) do
    validate_undefined_slot(slot, __CALLER__)

    quote do
      !!var!(assigns)[unquote(slot)]
    end
  end

  defmacro slot_assigned?({{:., _, [{:assigns, _, _}, slot_name]}, _, _} = slot) do
    validate_undefined_slot(slot_name, __CALLER__)

    quote do
      !!unquote(slot)
    end
  end

  defp validate_undefined_slot(slot_name, caller) do
    defined_slots =
      API.get_slots(caller.module)
      |> Enum.map(& &1.name)
      |> Enum.uniq()

    if slot_name not in defined_slots do
      similar_slot_message =
        case Helpers.did_you_mean(slot_name, defined_slots) do
          {similar, score} when score > 0.8 ->
            "\n\n  Did you mean #{inspect(to_string(similar))}?"

          _ ->
            ""
        end

      existing_slots_message =
        if defined_slots == [] do
          ""
        else
          slots =
            defined_slots
            |> Enum.map(&to_string/1)
            |> Enum.sort()

          available = Helpers.list_to_string("slot:", "slots:", slots)
          "\n\n  Available #{available}"
        end

      message = """
      no slot "#{slot_name}" defined in the component '#{caller.module}'\
      #{similar_slot_message}\
      #{existing_slots_message}\
      """

      IOHelper.warn(message, caller)
    end
  end

  defp runtime_props!(props, module, node_alias, ctx) do
    props
    |> Enum.map(fn
      {:__root__, value} -> maybe_root_prop(module, node_alias, ctx, value)
      {name, value} -> {name, value}
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {name, values} ->
      runtime_value = TypeHandler.runtime_prop_value!(module, name, values, [], node_alias, nil, ctx)
      {name, runtime_value}
    end)
  end

  defp maybe_root_prop(module, node_alias, ctx, value) do
    case Enum.find(module.__props__(), & &1.opts[:root]) do
      nil ->
        message = """
        no root property defined for component <#{node_alias}>

        Hint: you can declare a root property using option `root: true`
        """

        IOHelper.warn(message, %Macro.Env{module: ctx.module}, ctx.file, ctx.line)
        nil

      root_prop ->
        {root_prop.name, value}
    end
  end

  defp annotate_content do
    Code.ensure_loaded?(Phoenix.LiveView.HTMLEngine) &&
      function_exported?(Phoenix.LiveView.HTMLEngine, :annotate_body, 1) &&
      (&Phoenix.LiveView.HTMLEngine.annotate_body/1)
  end
end
