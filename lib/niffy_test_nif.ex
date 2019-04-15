defmodule NiffyTest.NifTest do
  use Niffy
  import Niffy

  #def woohoo(a) do
  #  case a do
  #    1 -> :woo
  #    2 -> 1
  #    _ -> a + 2
  #  end
  #end

  defboth woohoo(a) do
    case a do
      1 -> :woo
      2 -> 1
      _ -> a + 2
    end
  end

  #defboth raise_error() do
  #  raise "oops"
  #end

  defboth test_closure(a) do
    fn (b) ->
      a + b
    end
  end

  #defboth lambda_add(a, b) do
  #  fun = fn x -> a + x end
  #  fun.(b)
  #end

  #defboth testing(a) do
  #  Enum.map(a, fn (x) -> x * 2 end)
  #end

end

