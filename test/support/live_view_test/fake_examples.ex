defmodule Surface.LiveViewTestTest.FakeExamples do
  use Surface.Catalogue.Examples,
    subject: Surface.LiveViewTestTest.FakeComponent,
    title: "Fake examples"

  @example true
  def example_without_opts(assigns), do: ~F[]

  @example title: "Example with opts"
  def example_with_opts(assigns), do: ~F[]

  @example assert: "the code"
  def example_with_assert_text(assigns), do: ~F[the code]

  @example assert: ["the", "code"]
  def example_with_assert_texts(assigns), do: ~F[the code]
end
