defmodule NiffyTest.Macro do

  # {{:., [line: 16], [{:__aliases__, [line: 16], [:NiffyTest, :NifTest]}, :woohoo]},
  # [line: 16], [1]}
  
  def cmp_resp(
    {:catch, :error, :function_clause}, 
    {:catch, :error, {:error, {:function_clause, _}, :internal_err_data}}
  ), do: true
  def cmp_resp(
    {:catch, :error, err_typ1},
    {:catch, :error, {:error, err_typ2, :internal_err_data}}
  ) when err_typ1 == err_typ2, do: true
  def cmp_resp(a, b), do: a == b

  defmacro compare_native(invocation) do
    {{:., meta_i, [path, fun_name]}, meta_o, args} = invocation
    alt_fun_name = String.to_atom("#{fun_name}_orig")
    alt_invocation = {{:., meta_i, [path, alt_fun_name]}, meta_o, args}
    quote do
      orig = try do
        {:ok, unquote(alt_invocation)}
      catch
        a, b -> {:catch, a, b}
      end
      native = try do
        {:ok, unquote(invocation)}
      catch
        a, b -> {:catch, a, b}
      end
      IO.inspect {:resp, orig, native}
      if !cmp_resp(orig, native) do
        assert(orig == native)
      end
    end
  end

end

defmodule NiffyTest do
  use ExUnit.Case
  doctest Niffy
  import NiffyTest.Macro

  test "basic case" do
    compare_native(NiffyTest.NifTest.basic_case(1))
    compare_native(NiffyTest.NifTest.basic_case(2))
    compare_native(NiffyTest.NifTest.basic_case(3))
    compare_native(NiffyTest.NifTest.basic_case(4))
    compare_native(NiffyTest.NifTest.basic_case(:doo))
    compare_native(NiffyTest.NifTest.basic_case(:foo))
  end

  test "map put" do
    compare_native(NiffyTest.NifTest.map_put(%{}, :a, :b))
    compare_native(NiffyTest.NifTest.map_put(:a, :b, :c))
  end

  test "fib" do
    compare_native(NiffyTest.NifTest.fib(5))
    compare_native(NiffyTest.NifTest.fib(:a))
    compare_native(NiffyTest.NifTest.fib(-1))
  end

  #test "closures" do
  #  IO.inspect NiffyTest.NifTest.test_closure(1)
  #  IO.inspect NiffyTest.NifTest.test_closure_orig(1)
  #  :a = :b
  #end

end
