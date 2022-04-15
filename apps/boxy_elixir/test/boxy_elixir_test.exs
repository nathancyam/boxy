defmodule BoxyElixirTest do
  use ExUnit.Case
  doctest BoxyElixir

  test "greets the world" do
    assert BoxyElixir.hello() == :world
  end
end
