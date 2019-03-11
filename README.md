# Niffy

Elixir library that compiles functions automatically to native code and loads 
them as NIFs.

Uses [Eir](https://github.com/eirproject/eir) to compile Core Erlang to LLVM IR, 
links it as a NIF and loads it. 

This is mostly a proof of concept at the moment, it doesn't do anything useful 
yet. Mostly used to ease correctness testing of Eir at the moment, but the 
following things are on the short term roadmap:

[x] Basic NIF generation
[ ] Support more of Eir in LLVM code generation
[ ] Type specialization
[ ] SIMD intrinsics

## Example

The following is a small example using Niffy. 

```elixir
defmodule NiffyTest.NifTest do
  use Niffy

  # The following function will be compiled to native code and loaded
  # as a NIF.

  @niffy true
  def woohoo(a) do
    case a do
      1 -> :woo
      2 -> 1
      _ -> a + 2
    end
  end

end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `niffy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:niffy, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/niffy](https://hexdocs.pm/niffy).

LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libedit.so mix test
