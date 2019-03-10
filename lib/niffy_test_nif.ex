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

end

