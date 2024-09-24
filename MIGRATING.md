# Migrating to `v0.12.x`

### Forms

Component `<Form>` and all its related input components (`<TextInput>`, `<Checkbox>`, etc.) have been
deprecated and moved to a separate project called `surface_form_helpers`. The reason those components were created
in the first place was to add support for [scope-aware contexts](https://www.surface-ui.org/contexts#scope-aware-context)
to forms. Since this feature has been deprecated due to the lack of built-in support in Liveview, we strongly
recommend using the new built-in [<.form>](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#form/)
component, along with [Phoenix.HTML.Form](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html) and
[Phoenix.HTML.FormField](https://hexdocs.pm/phoenix_html/Phoenix.HTML.FormField.html) structs. This new Liveview API
is way more efficient regarding diff-tracking and should be the default way to desing forms.

If you're not able to update all your forms at once, `surface_form_helpers` can be used as a safe fallback so you can
gradually replace them.

### Using `surface_form_helpers`

```elixir
def deps do
  [
    {:surface_form_helpers, "~> 0.1.0"}
  ]
end
```

### Surface Catalogue

In case you're using `surface_catalogue` and have examples using `Surface.Catalogue.Example`, you need to
rename those with `Surface.Catalogue.LiveExample`. Pay attention that you should use `LiveExample` mostly
if your example requires manipulating state (data) through `handle_event` callbacks. For stateless examples,
use `Surface.Catalogue.Examples` instead, as it allows defining multiple examples on a single module.

# Migrating from `v0.7.x` to `v0.8.x`

Historically, most of the updates that require changes in your code, can be automatically
done by `mix surface.convert`, however, as we move forward to unify the API with Liveview, some of the
changes in `v0.8` may require user intervention as the converter might not be able to automatically
patch the project. For such cases, we adjusted the compiler to provide assertive warnings to help you
with the migration process. The main changes of that kind are related to the context and slot APIs.

## The new Context API

The context API have been extended and fully redesigned to improve its use and make it more friendly for
diff tracking. The compiler is able now to detect many cases where the use of contexts might impact
performance and suggest one or more alternative approaches to achieve the same goal. We recommend you
to carefully read each warning with care and follow the instructions that best suits your particular case.

Aside from the warnings, the only breaking change is that context values are no longer automatically
propagated through slots. Components that need to pass values to the parent scope via slots must
explicitly set `propagate_context_to_slots: true` in `config.exs`:

```elixir
config :surface, :components, [
  {Surface.Components.Form, propagate_context_to_slots: true},
]
```

The compiler will raise an error whenever it finds a component that can potentially propagate context
values through slots. If you don't want to use contexts at all, you need to set `propagate_context_to_slots`
to `false` to suppress the error for that component.

> **NOTE:** The following built-in Surface components are already configured to propagate context to slots:
> `Surface.Components.Form,`, `Surface.Components.Form.Field`, `Surface.Components.Form.FieldContext` and
> `Surface.Components.Form.Inputs`.

## The new Slot API

The slot API for arguments and generators have changed to make it similar to Liveview.

### Rendering Slots

Previously the reference was given in a combination of the `for`, `name` and `index` arguments.
Now the slot reference is given as the first argument of the root property: `<#slot {@name} />`.

> The converter doesn't update any `<#slot>` that has the `index` property.

### Slot argument(s)

Previous versions of Surface only allowed the syntax `slot default, args: [:index]` and `<#slot arg={index: 10}>`,
in other words we always required the argument to be a map. Now the argument can be any value and in `:let` we can
pattern match more freely and be compatible with Liveview slots/components.

Now the slot argument is given as the second argument of the root property: `<#slot {@name, argument} />`.

### Slot generator

The changes to generator are too complex for the converter to handle, the compiler errors/warnings will guide you through
the needed changes.

```elixir
# before
prop items, :list
slot cols, args: [item: ^items]
~F"""
{#for item <- @items}
  <#slot :args={item: item} />
{/for}
"""
```

```elixir
# after
prop items, :generator
slot cols, generator_prop: :items
~F"""
{#for item <- @items}
  <#slot generator_value={item} />
{/for}
"""
```

## Running `mix surface.convert`

This guide provides detailed instructions on how to run the built-in converter to automatically
apply required changes to your project's source code to make it compatible
with Surface `v0.8`.

> **NOTE:**  The current converter was designed to run against projects depending on Surface `>= v0.7.x`.
> If you're using an older version, you should first update it to each one of the previous versions
> all the way to `v0.7`. See: [previous versions](#previous-versions)

### Limitations of the converter

* By design, the converter doesn't touch Surface code inside documentation or macro components. If you have
  any code written inside `<!-- -->` or `<#Raw>...</#Raw>`, you need to convert it manually.

* Running the converter on a project that has already been converted may generate invalid code. If anything goes
  wrong with the conversion, make sure you revert the changes before running it again.

## Before converting the project

  1. Make sure you have committed your work or have a proper backup before running the converter. It may touch
  a lot of files so it's recommended to have a safe way to rollback the changes in case anything goes wrong.

  2. Check your dependencies. In case your project depends on a library using an older Surface version, it might start
  emitting warnings or even fail to compile after updating Surface. If that's the case, please consider running
  the converter against it and submitting a PR with the updated code. The steps to convert a dependency are the
  same described in this guide.

  3. Check that your `.formatter` has the configuration about the components you want to convert.
  The [plugin documentation](https://hexdocs.pm/surface/Surface.Formatter.Plugin.html#module-formatter-exs-setup) has the instructions.

## Steps to run the converter

Update `mix.exs` to use the new version:

```elixir
  defp deps do
    [
      {:surface, "~> 0.8.0"},
      ...
    ]
  end
```

Compile the dependencies:

```shell
mix clean && mix deps.get && mix deps.compile
```

Compile the project and fix all compilation errors, changes to the slot generator API are not handled by the converter.

```shell
mix compile
```

Run the converter:

```shell
mix surface.convert
```

Compile the converted project:

```shell
mix compile
```

## Expected changes

| Subject                       | Examples (Old syntax -> New syntax)                                                           |
| ----------------------------- | --------------------------------------------------------------------------------------------- |
| Slot Entry                    | `<#template>` -> `<:default>`   |
| Slot Entry                    | `<#template slot="header">` -> `<:header>`   |
| `<#slot for>`                  | `<#slot for={@name}>` -> `<#slot {@name}>`                                             |
| `<#slot name>`                 | `<#slot name="name">` -> `<#slot {@name}>`                                             |
| `<#slot :args>`                | `<#slot :args={name: "Joe", age: "32"}>` -> `<#slot {@default, name: "Joe", age: 35}>` |

## Reporting issues

In case you run into any trouble while running the converter, please open an issue at <https://github.com/surface-ui/surface/issues/>
providing detailed information about the problem, including the error message (if any) and a snippet of the
related code.

## Previous versions

* Migrating from `v0.6.x` to `v0.7.x`

  No converter was needed.

* [Migrating from `v0.5.x` to `v0.6.x`](https://github.com/surface-ui/surface/blob/v0.7/MIGRATING.md#migrating-from-v05x-to-v06x)

  Surface `v0.6.x` relies on the Liveview features available since `v0.16`. The main change
  from the user perspective is that the stateless `Surface.Component` now is built on top of
  `Phoenix.Component` instead of `Phoenix.LiveComponent`. This means the `mount/1`, `preload/1`
  and `update/2` callbacks are no longer available. If you initialize any assign or compute
  any value using those callbacks, you need to replace them with one of the new
  [assign helpers](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#module-assigns).

* [Migrating from `v0.4.x` to `v0.5.x`](https://github.com/surface-ui/surface/blob/v0.5/MIGRATING.md#migrating-from-v04x-to-v05x)

  Surface `v0.5.0` introduces a new syntax which requires migrating components written in previous versions.
  In order to make the migration process as smooth as possible, Surface `v0.5.x` ships with a converter that
  can automatically translate the old syntax into the new one.
