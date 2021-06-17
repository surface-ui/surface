# Surface

[![Build Status](https://github.com/surface-ui/surface/workflows/CI/badge.svg)](https://github.com/surface-ui/surface/actions?query=workflow%3A%22CI%22)

Surface is a **server-side rendering** component library that allows developers to
build **rich interactive user-interfaces**, writing minimal custom Javascript.

Built on top of [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/) and its new
[LiveComponent](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html), Surface
leverages the amazing Phoenix Framework to provide a **fast** and **productive** solution to build
modern web applications.

Full documentation and live examples can be found at [surface-ui.org](https://surface-ui.org).

### Example

```elixir
# Defining the component

defmodule Hello do
  use Surface.Component

  @doc "Someone to say hello to"
  prop name, :string, required: true

  def render(assigns) do
    ~F"""
    Hello, {@name}!
    """
  end
end

# Using the component

defmodule Example do
  use Surface.Component

  def render(assigns) do
    ~F"""
    <Hello name="John Doe"/>
    """
  end
end
```

## Features

  * **An HTML-centric** templating language, designed specifically to improve development experience.

  * **Components as modules** - they can be stateless, stateful, renderless or compile-time.

  * **Declarative properties** - explicitly declare the inputs (properties and events) of each component.

  * **Slots** - placeholders declared by a component that you can fill up with **custom content**.

  * **Contexts** - allows a parent component to share data with its children without passing them as properties..

  * **Compile-time checking** of the template structure, components' properties, slots, events and more.

  * **Integration with editor/tools** for warnings/errors, syntax highlighting, jump-to-definition,
    auto-completion (soon!) and more.

## Installation

Phoenix v1.5 comes with built-in support for LiveView apps. You can create a new application with:

```
mix phx.new my_app --live
```

Then add `surface` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:surface, "~> 0.5.0"}
  ]
end
```

If you're using `mix format`, make sure you add `:surface` to the `import_deps`
configuration in your `.formatter.exs` file:

```elixir
[
  import_deps: [:ecto, :phoenix, :surface],
  ...
]
```

For further information regarding installation, including how to quickly get started
using a boilerplate, please visit the [Getting Started](https://surface-ui.org/getting_started)
guide.

## Migrating from `v0.4.x` to `v0.5.x`

Surface `v0.5.0` introduces a new syntax which requires migrating components written in previous versions.
In order to make the migration process as smooth as possible, Surface `v0.5.x` ships with a converter that
can automatically translate the old syntax into the new one.

Please see the [Migration Guide](MIGRATING.md) for details.

## Tooling

  * [Surface Formatter](https://github.com/surface-ui/surface_formatter) - A code formatter for Surface.
  * [Surface package for VS Code](https://marketplace.visualstudio.com/items?itemName=msaraiva.surface) - Syntax highlighting support for Surface/Elixir.

## License

Copyright (c) 2020, Marlus Saraiva.

Surface source code is licensed under the [MIT License](LICENSE.md).