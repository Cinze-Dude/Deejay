defmodule DeejayTest do
  use ExUnit.Case
  doctest Deejay

  test "greets the world" do
    assert Deejay.hello() == :world
  end
end
