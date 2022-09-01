defmodule <%= inspect(web_module) %>.Demo do
  use Surface.LiveView

  alias <%= inspect(web_module) %>.Components.Card

  def render(assigns) do
    ~F"""
    <style>
      .flex {
        display: flex;
      }

      .items-center {
        align-items: center;
      }

      .justify-center {
        justify-content: center;
      }

      .h-screen {
        height: 100vh;
      }

      .tag {
        display: inline-block;
        background-color: #ddd;
        border-radius: 9999px;
        padding: 10px 8px;
        color: #888;
        font-weight: 500;
      }
    </style>

    <div class="flex items-center justify-center h-screen">
      <Card rounded>
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
