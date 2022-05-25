defmodule Surface.LiveViewTestTest.FakeExampleForOtherFakeComponent do
  use Surface.Catalogue.Example,
    subject: Surface.LiveViewTestTest.OtherFakeComponent,
    title: "A fake example"

  def render(assigns), do: ~F[]
end
