defmodule Niffy.CompilerNif do
  use Rustler, otp_app: :niffy, crate: "niffy_compilernif"

  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  def ctx_new(), do: :erlang.nif_error(:nif_not_loaded)
  def ctx_add_module(_ctx, _module_core), do: :erlang.nif_error(:nif_not_loaded)
  def ctx_add_builtins(_ctx, _functions), do: :erlang.nif_error(:nif_not_loaded)
  def ctx_add_root_functions(_ctx, _functions), do: :erlang.nif_error(:nif_not_loaded)
  def ctx_query_required_modules(_ctx), do: :erlang.nif_error(:nif_not_loaded)
  def ctx_compile_module_nifs(_ctx, _exported_funs), do: :erlang.nif_error(:nif_not_loaded)

end
