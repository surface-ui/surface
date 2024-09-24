# Surface

[![Build Status](https://github.com/surface-ui/surface/workflows/CI/badge.svg)](https://github.com/surface-ui/surface/actions?query=workflow%3A%22CI%22)

Surface is a **server-side rendering** component library that allows developers to
build **rich interactive user-interfaces**, writing minimal custom JavaScript.

Built on top of [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/) and its component API,
Surface leverages the amazing Phoenix Framework to provide a **fast** and **productive** solution
to build modern web applications.

Full documentation and live examples can be found at [surface-ui.org](https://surface-ui.org).

## Example

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

* **Contexts** - allows a parent component to share data with its children without passing them as properties.

* **Compile-time checking** of the template structure, components' properties, slots, events and more.

* **Integration with editor/tools** for warnings/errors, syntax highlighting, jump-to-definition,
    auto-completion (soon!) and more.

## Installation

Phoenix v1.7 comes with built-in support for LiveView apps. You can create a new phoenix application with:

```bash
mix phx.new my_app
```

> **Note:** In case you want to add Surface to an existing Phoenix application that doesn't have
LiveView properly installed, please see Phoenix Liveview's installation instructions at
[hexdocs.pm/phoenix_live_view/installation.html](https://hexdocs.pm/phoenix_live_view/installation.html).

Add `surface` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:surface, "~> 0.12.0"}
  ]
end
```

## Configuring the project using `mix surface.init`

After fetching the dependencies with `mix deps.get`, you can run the `surface.init` task to
update the necessary files in your project.

In case you want the task to also generate a sample component for you, use can use the `--demo` option.
A liveview using the component will be available at the `/demo` route.

Additionally, the task can also set up a [Surface Catalogue](https://github.com/surface-ui/surface_catalogue/)
for your project using the `--catalogue` option. The catalogue will be available at `/catalogue`.

> **Note:** When using the `--demo` and `--catalogue` options together, the task also generates two
> catalogue examples and a playground for the sample component.

```bash
mix surface.init --demo --catalogue
```

Start the Phoenix server with:

```bash
mix phx.server
```

That's it! You can now access your application at <http://localhost:4000>.

You can see the full list of options provided by `surface.init` by running:

```bash
mix help surface.init
```

For further information regarding installation, including how to install Surface manually,
please visit the [Getting Started](https://surface-ui.org/getting_started) guide.

## Migrating from previous versions

Please see the [Migration Guide](MIGRATING.md) for details.

## Tooling

* [Surface Formatter](https://github.com/surface-ui/surface_formatter) - A code formatter for Surface.
* [Surface package for VS Code](https://marketplace.visualstudio.com/items?itemName=msaraiva.surface) - Syntax highlighting support for Surface/Elixir.

## License

Copyright (c) 2020, Marlus Saraiva.

Surface source code is licensed under the [MIT License](LICENSE.md).
