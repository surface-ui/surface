defmodule Mix.Tasks.Compile.Surface.Definitions do
  @moduledoc false
  alias Surface.Directive.Events

  @default_output_dir "#{Mix.Project.build_path()}/definitions/"

  def run(specs, opts \\ []) do
    generate_definitions? = Keyword.get(opts, :generate_definitions, true)

    if generate_definitions? do
      do_run(specs, opts)
    else
      []
    end
  end

  defp do_run(specs, opts) do
    output_dir = Keyword.get(opts, :definitions_output_dir, @default_output_dir)
    generate_definitions(specs, output_dir)
    []
  end

  defp generate_definitions(specs, output_dir) do
    definitions =
      for %{type: type} = spec <- specs do
        case type do
          :surface ->
            %{
              name: spec.module,
              alias: get_alias(spec.module)
            }

          type when type in [:def, :defp] ->
            %{
              name: "#{spec.module}.#{spec.func}",
              alias: ".#{spec.func}"
            }
        end
      end
      |> Enum.sort_by(& &1.name)

    components_by_name =
      for %{type: type} = spec <- specs, into: %{} do
        case type do
          :surface ->
            {spec.module, spec}

          type when type in [:def, :defp] ->
            {"#{spec.module}.#{spec.func}", spec}
        end
      end

    File.mkdir_p!(output_dir)

    components_file = Path.join(output_dir, "components.json")
    # TODO: add config `definitions_pretty`, default: false
    components_content = Phoenix.json_library().encode!(definitions, pretty: true)
    File.write!(components_file, components_content)

    components_by_name_file = Path.join(output_dir, "components_by_name.json")
    components_by_name_content = Phoenix.json_library().encode!(components_by_name, pretty: true)
    File.write!(components_by_name_file, components_by_name_content)

    common_file = Path.join(output_dir, "common.json")
    common_content = Phoenix.json_library().encode!(get_common_definitions(), pretty: true)
    File.write!(common_file, common_content)
  end

  defp get_common_definitions() do
    surface_directive_reference = %{
      label: "Surface's \"Directive\"",
      link: "https://surface-ui.org/template_syntax#directives"
    }

    directives_specs = %{
      ":if" => %{
        type: "expression",
        doc: """
        Conditionally render a tag (or component).

        The code will be rendered if the expression is evaluated to a truthy value.
        """,
        reference: surface_directive_reference
      },
      ":for" => %{
        type: "expression",
        doc: """
        Iterates over a list (generator) and renders the content of the tag (or component) for each item in the list.
        """,
        reference: surface_directive_reference
      },
      ":show" => %{
        type: "any",
        doc: """
        Conditionally shows/hides an HTML tag, keeping the rendered element in
        the DOM even when the value is `false`.
        """,
        reference: surface_directive_reference
      },
      ":let" => %{
        type: "expression",
        doc: """
        Declares which slot arguments will be used in the current scope.

        For more info on slots arguments, see [Slot arguments](https://surface-ui.org/slots#slot-arguments)
        in Surface's website.
        """,
        reference: surface_directive_reference
      },
      ":values" => %{
        type: "expression",
        doc: """
        Defines a list of values to be sent to the server when dispatching events. It generates
        multiple `phx-value-*`. One for each key-value passed.

        The list of values can be either a keyword list or a map. The values will always be serialized as **strings**.

        ### Example

        ```surface
          <div :values={id: @id, group: @group}>
        ```
        """,
        reference: surface_directive_reference
      },
      ":hook" => %{
        doc: """
        Sets a hook via phoenix's `phx-hook` to handle custom client-side JavaScript when an element
        is added, updated, or removed by the server.

        More information on `phx-hook` can be found at
        [Client hooks via `phx-hook`](https://hexdocs.pm/phoenix_live_view/js-interop.html#client-hooks-via-phx-hook).

        For a better development experience, Surface automatically loads JS hooks
        related to your components when a colocated `.hooks.js` file is present.

        ### Example

        Export your hook as `default` in the colocated JS file:

        ```js
        export default {
          mounted(){
            console.log("Card mounted")
          }
        }
        ```

        Use the `:hook` directive to bind the hook to the HTML element:

        ```surface
        <div id="my_div" :hook>
          ...
        </div>
        ```
        """,
        type: "any",
        reference: %{
          label: "Surface's JS Interoperability",
          link: "https://surface-ui.org/js_interop"
        }
      }
    }

    events_directives_specs =
      for {group, events} <- Events.events_by_group(), event <- events, into: %{} do
        directive = ":on-#{event}"

        doc = """
        The `#{directive}` directive binds an event handler for client-server interaction using phoenix's `phx-#{event}` binding.

        If the template belongs to a live component, it automatically sets `phx-target` to `@myself`.

        ### Example

        ```surface
          <div #{directive}="my_event_handle">
            ...
          </div>
        ```
        """

        spec = %{
          type: "event",
          doc: doc,
          reference: event_reference_by_group(group)
        }

        {directive, spec}
      end

    phx_events_attributes_specs =
      for {group, events} <- Events.events_by_group(), event <- events, into: %{} do
        attr = "phx-#{event}"

        doc = """
        The `#{attr}` attribute binds an event handler for client-server interaction on `#{event}` events.

        ### Example

        ```surface
          <div #{attr}="my_event_handler">
            ...
          </div>
        ```
        """

        spec = %{
          type: "event",
          doc: doc,
          reference: event_reference_by_group(group)
        }

        {attr, spec}
      end

    %{
      directives_specs: Map.merge(directives_specs, events_directives_specs),
      # TODO: other bindings
      tag_attributes_specs: phx_events_attributes_specs,
      tag_directives: [":if", ":for", ":show", ":hook", ":values"] ++ Enum.map(Events.names(), &":on-#{&1}"),
      component_directives: [":if", ":for"],
      macro_component_directives: [":if", ":for"],
      slot_entry_directives: [":let"],
      slot_directives: [":if", ":for"],
      slot_props_specs: %{
        generator_value: %{
          type: "expression",
          reference: %{
            label: "Surface's \"Slot\" page",
            link: "https://surface-ui.org/slots#slot-generators"
          },
          doc: """
          Passes the value of the generator's current item to the slot entry.

          The generator must be a `prop` of type `:generator`, which must
          be bound to the slot through the `generator_prop` option.

          ### Example

          ```elixir
          defmodule Grid do
            use Surface.Component

            prop items, :generator, required: true
            slot cols, generator_prop: :items
          end
          ```

          ```surface
          <tbody>
            {#for item <- @items}
              <tr class={"is-selected": item[:selected]}>
                {#for col <- @cols}
                  <td><#slot {col} generator_value={item} /></td>
                {/for}
              </tr>
            {/for}
          </tbody>
          ```
          """
        }
      }
    }
  end

  defp get_alias(component) do
    component
    |> String.split(".")
    |> List.last()
  end

  defp event_reference_by_group(group) do
    case group do
      :focus ->
        %{
          label: "Phoenix's \"Focus and Blur Events\"",
          link: "https://hexdocs.pm/phoenix_live_view/bindings.html#focus-and-blur-events"
        }

      :scroll ->
        %{
          label: "Phoenix's \"Scroll Events and Infinite Stream pagination\"",
          link: "https://hexdocs.pm/phoenix_live_view/bindings.html#scroll-events-and-infinite-stream-pagination"
        }

      group ->
        %{
          label: "Phoenix's \"#{String.capitalize("#{group}")} Events\"",
          link: "https://hexdocs.pm/phoenix_live_view/bindings.html##{group}-events"
        }
    end
  end
end
