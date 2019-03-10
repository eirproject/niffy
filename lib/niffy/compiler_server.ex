defmodule Niffy.CompilerServer do
  use GenServer

  # Client
  def ensure_started() do
    case GenServer.start(__MODULE__, [], name: Niffy.CompilerServer) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  def add_module_code(pid, module, code) do
    GenServer.call(pid, {:add_module_code, module, code})
  end

  # Server
  
  defstruct ctx: nil

  def init([]) do
    {:ok, %__MODULE__{
      ctx: Niffy.CompilerNif.ctx_new(),
    }}
  end

  def handle_call({:add_module_code, module, code}, _from , state) do

    {:ok, extracted_module_name} = Niffy.CompilerNif.ctx_add_module(state.ctx, code)
    ^extracted_module_name = Atom.to_string(module)
    {:reply, :ok, state}
  end

end
