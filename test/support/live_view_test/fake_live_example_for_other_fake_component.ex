defmodule Surface.LiveViewTestTest.FakeLiveExampleForOtherFakeComponent do
  use Surface.Catalogue.LiveExample,
    subject: Surface.LiveViewTestTest.OtherFakeComponent,
    title: "A fake example"

  def render(assigns), do: ~F[]
end
