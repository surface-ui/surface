defmodule Surface.Components.FakeButton do
  @moduledoc """
  Fake form docs
  """

  use Surface.Component

  @doc """
  The button's type
  """
  prop type, :string, default: "button"

  @doc "The button's label"
  prop label, :string

  @doc "The button's color"
  prop color, :string, default: "white"

  prop map, :map

  def render(assigns) do
    ~F"""
    Fake render
    """
  end
end
