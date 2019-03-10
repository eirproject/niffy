defmodule NiffyTest.Macro do

  # {{:., [line: 16], [{:__aliases__, [line: 16], [:NiffyTest, :NifTest]}, :woohoo]},
  # [line: 16], [1]}

  defmacro compare_native(invocation) do
    {{:., meta_i, [path, fun_name]}, meta_o, args} = invocation
    alt_fun_name = String.to_atom("#{fun_name}_orig")
    alt_invocation = {{:., meta_i, [path, alt_fun_name]}, meta_o, args}
    quote do
      orig = try do
        {:ok, unquote(alt_invocation)}
      rescue
        x -> {:rescue, x}
      catch
        x -> {:catch, x}
      end
      native = try do
        {:ok, unquote(invocation)}
      rescue
        x -> {:rescue, x}
      catch
        x -> {:catch, x}
      end
      assert(orig == native)
    end
  end
end

defmodule NiffyTest do
  use ExUnit.Case
  doctest Niffy
  import NiffyTest.Macro

  test "greets the world" do
    compare_native(NiffyTest.NifTest.woohoo(1))
    compare_native(NiffyTest.NifTest.woohoo(2))
    compare_native(NiffyTest.NifTest.woohoo(3))
    compare_native(NiffyTest.NifTest.woohoo(4))
    compare_native(NiffyTest.NifTest.woohoo(:doo))
    compare_native(NiffyTest.NifTest.woohoo(:foo))
  end
end
