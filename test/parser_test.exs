defmodule TestParser do
  use Parser

  def parse(%BSON.ObjectId{} = value, :string) do
    BSON.ObjectId.encode!(value)
  end

  def parse(value, :object_id) when is_binary(value) do
    BSON.ObjectId.decode!(value)
  end
end

defmodule TestStruct do
  defstruct attrribute1: nil
end

defmodule ParserTest do
  use ExUnit.Case
  doctest Parser

  test "'is' function in parser" do
    assert TestParser.is(:integer, 10) == true
    assert TestParser.is(:text, 10) == false
    assert TestParser.is(:text, "text") == true
    assert TestParser.is(:map, %{value: nil}) == true
    assert TestParser.is(:struct, %TestStruct{}) == true
  end

  test "parse object id to string" do
    object_id = BSON.ObjectId.new(0, 0, 0, 0)
    assert TestParser.parse(object_id, :string) == BSON.ObjectId.encode!(object_id)
  end

  test "parse string to object_id" do
    object_id = BSON.ObjectId.new(0, 0, 0, 0)
    id = TestParser.parse(object_id, :string)
    assert TestParser.parse(id, :object_id) == object_id
  end
end
