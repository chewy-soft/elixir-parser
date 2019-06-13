defmodule Extension do
  defmacro extends(module) do
    module = Macro.expand(module, __CALLER__)
    functions = module.__info__(:functions)

    Enum.map(functions, fn {name, arity} ->
      args =
        if arity == 0 do
          []
        else
          Enum.map(1..arity, fn i ->
            {String.to_atom(<<?x, ?A + i - 1>>), [], nil}
          end)
        end

      signature = {name, [], args}
      IO.inspect(args)

      quote do
        defdelegate unquote(signature), to: unquote(module)
        defoverridable [{unquote(name), unquote(arity)}]
      end
    end)
  end
end
