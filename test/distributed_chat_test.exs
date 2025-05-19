defmodule DistributedChatTest do
  use ExUnit.Case
  doctest DistributedChat

  test "greets the world" do
    assert DistributedChat.hello() == :world
  end
end
