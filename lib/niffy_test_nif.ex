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
  
  #defboth do_reduce(a) do
  #  Enum.reduce(a, fn a, b -> a + b end)
  #end

  defboth basic_case(a) do
    case a do
      1 -> :woo
      2 -> 1
      _ -> a + 2
    end
  end

  defboth map_put(a, b, c) do
    a
    |> Map.put(b, c)
  end

  @niffy true
  def fib(0), do: 0
  def fib(1), do: 1
  def fib(n) when n > 0 do
    fib(n-1) + fib(n-2)
  end

  def fib_orig(0), do: 0
  def fib_orig(1), do: 1
  def fib_orig(n) when n > 0 do
    fib_orig(n-1) + fib_orig(n-2)
  end
  #def fib_orig(0), do: 0
  #def fib_orig(1), do: 1
  #def fib_orig(n) when n > 0, do: fib(n-1) + fib(n-2)

  #defboth raise_error() do
  #  raise "oops"
  #end

  #defboth test_closure(a) do
  #  fn (b) ->
  #    a + b
  #  end
  #end

  #defboth lambda_add(a, b) do
  #  fun = fn x -> a + x end
  #  fun.(b)
  #end

  #defboth testing(a) do
  #  Enum.map(a, fn (x) -> x * 2 end)
  #end

end

