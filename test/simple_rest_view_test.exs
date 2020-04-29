defmodule SimpleRestViewTest do
  use ExUnit.Case
  doctest SimpleRestView

  test "greets the world" do
    assert SimpleRestView.hello() == :world
  end
end
