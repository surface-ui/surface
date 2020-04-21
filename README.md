# test Surface

[![Build Status](https://travis-ci.com/msaraiva/surface.svg?branch=master)](https://travis-ci.com/msaraiva/surface)
[![Hex.pm version](https://img.shields.io/hexpm/v/surface.svg?style=flat)](https://hex.pm/packages/surface)

Surface is a **server-side rendering** component library that allows developers to
build **rich interactive user-interfaces**, writing minimal custom Javascript.

Built on top of [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/) and its new
[LiveComponent](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html), Surface
leverages the amazing Phoenix Framework to provide a **fast** and **productive** solution to build
modern web applications.

Full documentation and live examples can be found at [surface-demo.msaraiva.io](http://surface-demo.msaraiva.io).

A VS Code extension that adds support for syntax highlighting is available at
[marketplace.visualstudio.com](https://marketplace.visualstudio.com/items?itemName=msaraiva.surface).

### Example

![Example](images/example.png?raw=true)

## How does it work?

At compile time, Surface translates components defined in an extended HTML-like syntax
into regular Phoenix templates. It also translates standard HTML nodes allowing us to
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

> **Note:** Some of the features are still experimental and subject to change.

## Installation

Requirements:

  * Install Phoenix (https://hexdocs.pm/phoenix/installation.html).
  * Install Phoenix LiveView (https://hexdocs.pm/phoenix_live_view/installation.html)

Then add `surface` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:surface, "~> 0.1.0-alpha.1"}
  ]
end
```

In order to have `~H` available for any Phoenix view, add the following import to your web
file in `lib/my_app_web.ex`:

```elixir
  # lib/my_app_web.ex

  ...

  def view do
    quote do
      ...
      import Surface
    end
  end
```

For further information regarding installation, including how to quickly get started
using a boilerplate, please visit the [Getting Started](http://surface-demo.msaraiva.io/getting_started)
guide.

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
