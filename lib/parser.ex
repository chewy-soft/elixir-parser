defmodule Parser do
  defmacro __using__(opts) do
    quote do
      import Extension
      extends(unquote(__MODULE__))
    end
  end

  def default_by_type(type) do
    case type do
      {:array, _} -> []
      {:map, _} -> Map.new()
      {:struct, module} -> struct(module)
      _ -> nil
    end
  end

  def parse(value, :any), do: value

  def parse(%DateTime{} = value, :datetime) do
    value
  end

  def parse(value, :datetime!) do
    case value do
      %DateTime{} = value ->
        value

      value when is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _} -> datetime
          _ -> nil
        end

      _ ->
        nil
    end
  end

  def parse(value, :float) do
    (is_float(value) && value) || nil
  end

  def parse(value, :float!) do
    cond do
      is_float(value) ->
        value

      is_binary(value) ->
        case Float.parse(value) do
          {f, _} -> f
          _ -> nil
        end

      is_integer(value) ->
        value / 1

      true ->
        nil
    end
  end

  def parse(value, :atom) do
    (is_atom(value) && value) || nil
  end

  def parse(value, {:func, func}) when is_function(func) do
    func.(value)
  end

  def parse(value, {:func, mf}) when is_tuple(mf) do
    {m, f} = mf
    apply(m, f, value)
  end

  #def parse(%BSON.ObjectId{} = value, :string) do
  #  BSON.ObjectId.encode!(value)
  #end

  def parse(value, :atom!) do
    cond do
      value == "" -> nil
      is_binary(value) -> String.to_atom(value)
      is_atom(value) -> value
      true -> nil
    end
  end

  def parse(value, :string) do
    (is_binary(value) && value) || nil
  end

  def parse(value, :text) do
    parse(value, :string)
  end

  def parse(value, :boolean) do
    (value == true && true) || false
  end

  def parse(value, :boolean!) do
    if !value || value == "false" do
      false
    else
      true
    end
  end

  def parse(value, :integer) do
    (is_integer(value) && value) || nil
  end

  def parse(value, :integer!) do
    cond do
      value == "" -> nil
      is_binary(value) -> parse(value, :float!) |> Float.floor() |> round()
      is_float(value) -> Float.floor(value) |> round()
      is_integer(value) -> value
      true -> nil
    end
  end

  def parse(nil, type) do
    default_by_type(type)
  end

  def parse(list, {:array, type}) when is_list(list) do
    Enum.map(list, fn e ->
      parse(e, type)
    end)
  end

  def parse(_, {:array, _type}) do
    []
  end

  def parse(value, :object_id) do
    case value do
      %BSON.ObjectId{} = value ->
        value

      value when is_binary(value) ->
        BSON.ObjectId.decode!(value)

      _ ->
        nil
    end
  end

  def parse(map, {:struct, module}) when is_map(map) do
    Enum.reduce(module.__meta__, struct(module), fn {name, {type, opts}}, acc ->
      default = Keyword.get(opts, :default)
      sparse = Keyword.get(opts, :sparse, false)
      value = parse(map_get(map, name, default), type)

      case {sparse, value} do
        {true, nil} -> Map.delete(acc, name)
        {_, _} -> Map.put(acc, name, value)
      end
    end)
  end

  def parse(_, {:struct, module}) do
    struct(module)
  end

  def parse(map, {:map, {key_type, value_type}}) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(
        acc,
        parse(key, key_type),
        parse(value, value_type)
      )
    end)
  end

  def parse(_, {:map, {_key_type, _value_type}}), do: %{}

  defp map_get(map, key, default) when is_list(map) or is_map(map) do
    cond do
      is_atom(key) -> map_get_atom(map, key, default)
      is_binary(key) -> map_get_atom(map, String.to_atom(key), default)
    end
  end

  defp map_get_atom(map, key, default) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, to_string(key)) -> Map.get(map, to_string(key))
      true -> default
    end
  end

  def is(type, value) when is_atom(type) do
    case type do
      nil -> is_nil(value)
      :integer -> is_integer(value)
      :text -> is_binary(value)
      :map -> is_map(value)
      :list -> is_list(value)
      :float -> is_float(value)
      :array -> is_list(value)
      :struct -> is_struct(value)
    end
  end

  def has_meta?(module) do
    Keyword.has_key?(module.__info__(:functions), :__meta__)
  end

  def is_struct(value) do
    is_map(value) && Map.has_key?(value, :__struct__)
  end
end
