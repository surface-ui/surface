# Migrating from `v0.7.x` to `v0.8.x`

## The new Context API

The context API have been extended and fully redesigned to improve its use and make it more friendly for
diff tracking. The compiler is able now to detect many cases where the use of contexts might impact
performance and suggest one or more alternative approaches to achieve the same goal. We recommend you
to carefully read each warning with care and follow the instructions that best suit you perticular case.

Aside from the warnings, the only breaking change is that context values are no longer automatically
propagated through slots. Components that need to pass values to the parent scope via slots must
explicitly set `propagate_context_to_slots: true` in `config.exs`:

```elixir
config :surface, :components, [
  {Surface.Components.Form, propagate_context_to_slots: true},
]
```

The compile will emit a warning whenever it finds a component that can potentially propagate context
values through slots. If you don't want to use contexts at all, you need to set `propagate_context_to_slots`
to `false` to suppress the warning for that component.

> **NOTE:** The following built-in Surface components are already configured to propagate context to slots:
> `Surface.Components.Form,`, `Surface.Components.Form.Field`, `Surface.Components.Form.FieldContext` and
> `Surface.Components.Form.Inputs`.

## Expected changes

| Subject                       | Examples (Old syntax -> New syntax)                                                           |
| ----------------------------- | --------------------------------------------------------------------------------------------- |
| Templates                     | &bull; `<#template>` -> `<:default>`  <br> &bull; `<#template slot="header">` -> `<:header>`  |

# Migrating from `v0.5.x` to `v0.6.x`

`Surface.Component` now is built on top of function components instead of stateless live components. This decision implies some breaking changes described below with solutions that allow you updade your code smoothly.

## The `mount` and `update` callbacks are no longer available
Basically, any data preparation that was done inside those callbacks must be moved to `render/1`. The Phoenix Live View API has been updated so you can use [`assign`](https://hexdocs.pm/phoenix_live_view/0.16.4/Phoenix.LiveView.html#assign/2), [`assign_new`](https://hexdocs.pm/phoenix_live_view/0.16.4/Phoenix.LiveView.html#assign/2), etc. in any function component.

Before:
```elixir
defmodule StatelessComponent do
 use Surface.Component

 prop count, :string
 data count_mount, :string
 data count_updated, :string

 @impl true
 def mount(socket) do
   socket =
     socket
     |> assign(:count_mount, socket.assigns.count + 1)

   {:ok, socket}
 end

 @impl true
 def update(assigns, socket) do
   socket =
     socket
     |> assign(assigns)
     |> assign(:count_updated, assigns.count + 2)

   {:ok, socket}
 end

 @impl true
 def render(assigns) do
   ~F"""
   <div>{@count} - {@count_updated}</div>
   """
 end
end
```

After:
```elixir
defmodule StatelessComponent do
  use Surface.Component

  prop count, :string
  data count_mount, :string
  data count_updated, :string

  @impl true
  def render(assigns) do
    assigns =
      |> assign_new(:count_mount, fn -> assigns.count + 1 end) assigns
      |> assign(:count_updated, assigns.count + 2)

    ~F"""
    <div>{@count} - {@count_mount} - {@count_updated}</div>
    """
  end
end
```
## `@socket`  is no longer available in the `render` function and the `.sface` files

If you were using the `@socket` assign to render routes, you should now use the application `Endpoint` instead.


Before
```elixir
Routes.page_path(@socket, :show, "Hello")
# or
MyAppWeb.Router.Helpers.page_path(@socket, :show, "Hello")
```

After:
```elixir
Routes.page_path(MyAppWeb.Endpoint, :show, "Hello")
# or
MyAppWeb.Router.Helpers.page_path(MyAppWeb.Endpoint, :show, "Hello")
```

# Migrating from `v0.4.x` to `v0.5.x`

This guide provides detailed instructions on how to run the built-in converter to
translate Surface `v0.4` code into the new `v0.5` syntax.

## Limitations of the converter

  * By design, the converter doesn't touch Surface code inside documentation or macro components. If you have
  any code written inside `<!-- -->` or `<#Raw>...</#Raw>`, you need to convert it manually.

  * The replacement of `~H` with `~F` happens globally in a `.ex` (or `.exs`) file, i.e., the converter will
  replace any occurrence of `~H` followed by `"""`, `"`, `[`, `(` or `{`, including occurrences found in comments.

  * The replacement of `slot name, props: [...]` with `slot name, args: [...]` happens globally in a `.ex` (or `.exs`) file,
  i.e., the converter will replace any occurrence of it, even if found in comments.

  * Running the converter on a project that has already been converted may generate invalid code. If anything goes
  wrong with the conversion, make sure you revert the changes before running it again.

## Before converting the project

  1. Make sure you have committed your work or have a proper backup before running the converter. It may touch
  a lot of files so it's recommended to have a safe way to rollback the changes in case anything goes wrong.

  2. If you're using an earlier version of Surface, make sure you update it to `v0.4.1` and fix any deprecation
  warning that might be emitted. If you have too many warnings regarding
  `automatic conversion of string literals into atoms is deprecated and will be removed in v0.5.0` and you
  don't want to fix them manually, you can try @paulstatezny's
  [surface_atom_shorthand_converter](https://github.com/paulstatezny/surface_atom_shorthand_converter) to fix
  them all for you.

  3. Check your dependencies. For a safer migration, all dependencies providing Surface components should
  be converted before running the converter on the main project. Otherwise, you might not be able to compile your
  project in case any of those dependencies is using the invalid old syntax. If the dependency you need has not been
  updated yet, please consider running the converter against it and submitting a PR with the updated code. The steps
  to convert a dependency are the same described in this guide.

## Steps to run the converter

Update your `.formatter` informing about `.sface` files and any additional folder where you might have any component
to be converted:

```
[
  surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}", "priv/catalogue/**/*.{ex,exs,sface}"],
  ...
]

```

Update `mix.exs` to use the new version:

```
  defp deps do
    [
      {:surface, "~> 0.5.0"},
      ...
    ]
  end
```

Compile the dependencies:

```
mix clean && mix deps.get && mix deps.compile
```

Run the converter:

```
mix surface.convert
```

Compile the converted project:

```
mix compile
```

## Expected changes

| Subject                       | Examples (Old syntax -> New syntax)                                                                                                      |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Sigil                         | `~H"""` -> `~F"""`                                                                                                                       |
| Interpolation                 | `{{@value}}` -> `{@value}`                                                                                                               |
| Templates                     | `<template>` -> `<#template>`                                                                                                            |
| If                            | `<If condition={{ expr }}>` -> `{#if expr}`                                                                                              |
| For                           | `<For each={{ expr }}>` -> `{#for expr}`                                                                                                 |
| Interpolation in attr values  | `id="id_{{@id}}"` -> `id={"id_#{@id}"}`                                                                                                  |
| ErrorTag's `phx_feedback_for` | `<ErrorTag phx_feedback_for="..." />` -> `<ErrorTag feedback_for="..." />`                                                               |
| Non-string attr values        | &bull; `selected=true` -> `selected={true}` <br> &bull; `tabindex=1` -> `tabindex={1}`                                                   |
| Slots                         | &bull; `<slot :props={{ item: item }}>` -> `<#slot :args={item: item}>` <br> &bull; `slot name, props: [...]` -> `slot name, args: [...]`|

## Reporting issues

In case you run into any trouble while running the converter, please open an issue at https://github.com/surface-ui/surface/issues/
providing detailed information about the problem, including the error message (if any) and a snippet of the
related code.
