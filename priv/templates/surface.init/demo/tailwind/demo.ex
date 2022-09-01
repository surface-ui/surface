defmodule <%= inspect(web_module) %>.Demo do
  use Surface.LiveView

  alias <%= inspect(web_module) %>.Components.Card

  def render(assigns) do
    ~F"""
    <style>
      .tag {
        @apply bg-gray-200 rounded-full px-3 py-1 text-sm font-semibold text-gray-700 mr-2;
      }
    </style>

    <div class="flex items-center justify-center h-screen">
      <Card max_width="lg" rounded>
        <:header>
          Surface UI
        </:header>

        Start building rich interactive user-interfaces, writing minimal custom Javascript.
        Built on top of Phoenix LiveView, <strong>Surface</strong> leverages the amazing
        <strong>Phoenix Framework</strong> to provide a fast and productive solution to
        build modern web applications.

        <:footer>
          <span class="tag">#surface</span>
          <span class="tag">#phoenix</span>
          <span class="tag">#tailwindcss</span>
        </:footer>
      </Card>
    </div>
    """
  end
end
