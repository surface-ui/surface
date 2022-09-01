defmodule <%= inspect(web_module) %>.Components.CardPlayground do
  use Surface.Catalogue.Playground,
    subject: <%= inspect(web_module) %>.Components.Card,
    height: "360px",
    body: [style: "padding: 1.5rem;"]

    @props [
      rounded: true,
      max_width: "lg"
    ]

    @slots [
      header: "The header",
      default: """
              Start building rich interactive user-interfaces, writing minimal custom Javascript.
              Built on top of Phoenix LiveView, Surface leverages the amazing Phoenix Framework
              to provide a fast and productive solution to build modern web applications.
              """,
      footer: "#surface"
    ]
end
