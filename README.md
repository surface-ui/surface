# Surface

[![Build Status](https://github.com/surface-ui/surface/workflows/CI/badge.svg)](https://github.com/surface-ui/surface/actions?query=workflow%3A%22CI%22)

Surface is a **server-side rendering** component library that allows developers to
build **rich interactive user-interfaces**, writing minimal custom Javascript.

Built on top of [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/) and its new
[LiveComponent](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html), Surface
leverages the amazing Phoenix Framework to provide a **fast** and **productive** solution to build
modern web applications.

Full documentation and live examples can be found at [surface-ui.org](https://surface-ui.org).

A VS Code extension that adds support for syntax highlighting is available at
[marketplace.visualstudio.com](https://marketplace.visualstudio.com/items?itemName=msaraiva.surface).

### Example

```elixir
# Defining the component

defmodule Hello do
  use Surface.Component

  @doc "Someone to say hello to"
  prop name, :string, required: true

  def render(assigns) do
    ~H"""
    Hello, {{ @name }}!
    """
  end
end

# Using the component

defmodule Example do
  use Surface.Component

  def render(assigns) do
    ~H"""
    <Hello name="John Doe"/>
    """
  end
end
```

## How does it work?

Surface's custom compiler translates components defined in an extended HTML-like syntax
into Elixir's Abstract Syntax Tree (AST). It also translates standard HTML nodes, allowing to
extend their behaviour adding new features like syntactic sugar on attributes definition,
directives, static validation and more.

In order to have your code translated, you need to use the `~H` sigil when defining your templates.

## Features

  * **An HTML-centric** templating language with built-in directives (`:for`, `:if`, ...) and
    syntactic sugar for attributes (inspired by Vue.js).

  * **Components as modules** - they can be stateless, stateful, renderless or compile-time.

  * **Declarative properties** - explicitly declare the inputs (properties and events) of each component.

  * **Slots** - placeholders declared by a component that you can fill up with **custom content**.

  * **Contexts** - allows a parent component to share data with its children without passing them as properties..

  * **Compile-time checking** of components and their properties.

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
    {:surface, "~> 0.4.1"}
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

Surface v0.5.0 introduces a new syntax which requires migrating components written in previous versions.
In order to make the migration process as smooth as possible, Surface `v0.5.x` ships with a converter that
can automatically translate the old syntax into the new one.

Please follow the steps below to migrate your project.

### Before converting the project

1. Make sure you have commited your work or have a proper backup before running the converter. It may touch
a lot of files so it's recommended to have a safe way to rollback the changes in case anything goes wrong.

2. Check your dependencies. For a successful migration, all dependencies providing Surface components should also
be converted before running the converter. Otherwise, you might not be able to compile your project in case any
of those dependencies is using an invalid old syntax. If the dependency you need has not been updated yet,
plaese consider running the converter against it and submitting a PR with those changes. The steps to convert a
dependency are the same decribed here.

### Steps to run the converter

Update your `.formatter` informing about `.sface` files and any additional folder you might have any component to be converted:

```
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,priv/catalogue}/**/*.{ex,exs,sface}"],
  ...
]

```

Update `mix.exs` to use the new version:
```
  defp deps do
    [
      {:surface, github: "surface-ui/surface"},
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
mix Surface.ConvertSyntax
```

### Limitations

By design, the converter doesn't touch code inside documentation nor macro components. If you have
any code written inside `<!-- -->` or `<#Raw>...</#Raw>`, you need to convert it manually.

## Static checking

Since components are ordinary Elixir modules, some static checking is already provided
by the compiler. Additionally, we added a few extra warnings to improve user experience.
Here are some examples:

### Module not available

![Example](images/module_not_available.png?raw=true)

### Missing required property

![Example](images/required_property.png?raw=true)

### Unknown property

![Example](images/unknown_property.png?raw=true)

## Tooling

Some experimental work on tooling around the library has been done. Here's a few of them:

### VS Code

- [x] Syntax highlighting

### ElixirSense

- [x] Jump to definition of modules (components)
- [ ] Jump to definition of properties
- [ ] Auto-complete/suggestions for properties (WIP)
- [x] Show documentation on hover for components
- [ ] Show documentation on hover for properties

### Other tools

Having a standard way of defining components with typed properties allows us to
enhance tools that introspect information from modules. One already discussed was
the possibility to have `ex_doc` query that information to provide standard
documentation for properties, events, slots, etc.

## License

Copyright (c) 2020, Marlus Saraiva.

Surface source code is licensed under the [MIT License](LICENSE.md).