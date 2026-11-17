defmodule PlantoTest do
  use ExUnit.Case
  doctest Planto

  test "greets the world" do
    assert Planto.hello() == :world
  end
end
