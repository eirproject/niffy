defmodule Niffy do 

  #defp get_object_code(mod) when is_atom(mod) do
  #  path = :code.get_path()
  #  IO.inspect {1, path}
  #  mod_str = Atom.to_charlist(mod)
  #  IO.inspect {2, mod_str}
  #  if :erl_prim_loader.is_basename(mod_str) do
  #    mod_to_bin(path, mod, mod_str ++ :init.objfile_extension())
  #  else
  #    :error
  #  end
  #end

  #defp mod_to_bin([dir | tail], mod, mod_file) do
  #  file = :filename.append(dir, mod_file)
  #  IO.inspect {3, file}
  #  case :erl_prim_loader.get_file(file) do
  #    :error -> mod_to_bin(tail, mod, mod_file)
  #    {:ok, bin, _} ->
  #      case :filename.pathtype(file) do
  #        :absolute -> {mod, bin, file}
  #        _ -> {mod, bin, absname(file)}
  #      end
  #  end
  #end
  #defp mod_to_bin([], mod, mod_file) do
  #  case :erl_prim_loader.get_file(mod_file) do
  #    :error -> :error
  #    {:ok, bin, f_name} -> {mod, bin, absname(f_name)}
  #  end
  #end

  #defp absname(file) do
  #  case :erl_prim_loader.get_cwd() do
  #    {:ok, cwd} -> absname(file, cwd)
  #    _error -> file
  #  end
  #end
  #def absname(name, absbase) do
  #  case :filename.pathtype(name) do
  #    :relative -> :filename.absname_join(absbase, name)
  #    :absolute -> :filename.join([:filename.flatten(name)])
  #    #:volumerelative -> raise "unimplemented"
  #  end
  #end
  
  defp nif_include_dir do
    "#{:code.root_dir()}/erts-#{:erlang.system_info(:version)}/include/"
  end

  defp from_debug_info(module, backend, data) do
    case backend.debug_info(:erlang_v1, module, data, []) do
      {:ok, erlang_forms} ->
        from_erlang_forms(:to_core, module, erlang_forms)
    end
  end

  defp from_erlang_forms(format, module, forms) do
    case :compile.noenv_forms(forms, [format]) do
      {:ok, ^module, res} ->
        {:ok, :core_pp.format(res)}
    end
  end

  def beam_to_core(beam) do
    case :beam_lib.chunks(beam, [:debug_info]) do
      {:ok, {module, [debug_info: {:debug_info_v1, backend, data}]}} ->
        from_debug_info(module, backend, data)
    end
  end

  def mod_to_core(mod) do
    case :code.get_object_code(mod) do
      {^mod, beam, _file} -> beam_to_core(beam)
      _ -> :error
    end
  end

  def niffy_dir do
    build_path = Mix.Project.build_path()
    niffy_dir = Path.join(build_path, "niffy")
    case File.mkdir(niffy_dir) do
      :ok -> ()
      {:error, :eexist} -> ()
    end
    niffy_dir
  end

  def niffy_core_cache_file(mod) do
    niffy_dir = niffy_dir()
    file_name = Atom.to_string(mod) <> ".corecache"
    file_path = Path.join(niffy_dir, file_name)
  end

  def get_core(mod) do
    core_cache_file = niffy_core_cache_file(mod)
    case File.read(core_cache_file) do
      {:ok, core_code} -> {:ok, core_code}
      _ ->
        case mod_to_core(mod) do
          {:ok, core_code} -> {:ok, core_code}
          _ -> :error
        end
    end
  end

  def do_compile_nif(mod, env, to_compile) do
    ctx = Niffy.CompilerNif.ctx_new()

    IO.puts "Compiling #{inspect to_compile} in #{mod}"

    # Add the root module
    {:ok, core_code} = get_core(mod)
    {:ok, mod_bin} = Niffy.CompilerNif.ctx_add_module(ctx, core_code)
    ^mod_bin = Atom.to_string(mod)

    # Add dependencies
    # TODO
    Niffy.CompilerNif.ctx_query_required_modules(ctx, to_compile)

    Niffy.CompilerNif.ctx_compile_module_nifs(ctx, to_compile)

    {_, 0} = System.cmd("clang-7", ["-I", nif_include_dir(), "-O0", "-S", "-emit-llvm", "nif_lib.c"])
    {_, 0} = System.cmd("llc-7", ["-relocation-model=pic", "-filetype=obj", "nif_lib.ll"])
    {_, 0} = System.cmd("llvm-dis-7", ["module.bc"])
    {_, 0} = System.cmd("llc-7", ["-relocation-model=pic", "-filetype=obj", "module.bc"])
    {_, 0} = System.cmd("clang-7", ["-fPIC", "-shared", "-o", "output.so", "nif_lib.o", "module.o"])

    :ok
  end

  def cache_bytecode(env, bytecode) do
    {:ok, core_iolist} = beam_to_core(bytecode)
    core_code = :erlang.iolist_to_binary(core_iolist)
    file_path = niffy_core_cache_file(env.module)
    File.write!(file_path, core_code)
    
    :ok
  end

  def on_definition(env, kind, name, args, guards, body) do
    res = Module.get_attribute(env.module, :niffy)
    if res do
      Module.put_attribute(env.module, :niffy_accumulated_nifs, {env.module, name, length(args)})
    end
    Module.put_attribute(env.module, :niffy, nil)
  end

  defmacro before_compile(env) do
    quote do
      def on_module_load do
        Niffy.do_compile_nif(__MODULE__, __ENV__, @niffy_accumulated_nifs)
        :erlang.load_nif("/home/hansihe/proj/elixir/niffy/output", 0)
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :niffy, [])
      Module.register_attribute(__MODULE__, :niffy_accumulated_nifs, accumulate: true, persist: true)
      @before_compile {Niffy, :before_compile}
      @on_definition {Niffy, :on_definition}
      @after_compile {Niffy, :cache_bytecode}
      @on_load :on_module_load
    end
  end

  defmacro defboth(sig, body) do
    {fun_name, meta, args} = sig
    alt_fun_name = String.to_atom("#{fun_name}_orig")
    alt_sig = {alt_fun_name, meta, args}

    quote do
      @niffy true
      def(unquote(sig), unquote(body))
      def(unquote(alt_sig), unquote(body))
    end

  end

end
