#[macro_use] extern crate rustler;
#[macro_use] extern crate rustler_codegen;
#[macro_use] extern crate lazy_static;

use rustler::{Env, Term, NifResult, Encoder, ResourceArc, Error};
use rustler::types::atom::Atom;
use rustler::schedule::SchedulerFlags;

use std::thread::Builder;
use std::sync::Mutex;
use std::collections::{ HashMap, HashSet };
use std::path::Path;


use eir::{ Module, FunctionIdent };
use eir::Atom as EirAtom;

use gen_nif::CompilationContext;

struct CtxResource(Mutex<Ctx>);

struct Ctx {
    modules: HashMap<EirAtom, Module>,
    unresolved: HashSet<FunctionIdent>,
    resolved: HashSet<FunctionIdent>,
    builtins: HashSet<FunctionIdent>,
}

mod atoms {
    rustler_atoms! {
        atom ok;
        //atom error;
        //atom __true__ = "true";
        //atom __false__ = "false";
    }
}

rustler_export_nifs! {
    "Elixir.Niffy.CompilerNif",
    [
        ("ctx_new", 0, ctx_new),
        ("ctx_add_module", 2, ctx_add_module, SchedulerFlags::DirtyCpu),
        ("ctx_add_root_functions", 2, ctx_add_root_functions),
        ("ctx_add_builtins", 2, ctx_add_builtins),
        ("ctx_query_required_modules", 1, ctx_query_required_modules),
        ("ctx_compile_module_nifs", 2, ctx_compile_module_nifs),
    ],
    Some(on_load)
}

fn on_load<'a>(env: Env<'a>, _init_term: Term<'a>) -> bool {
    rustler::resource_struct_init!(CtxResource, env);
    true
}

fn ctx_new<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let ctx = Ctx {
        modules: HashMap::new(),
        unresolved: HashSet::new(),
        resolved: HashSet::new(),
        builtins: HashSet::new(),
    };
    Ok(ResourceArc::new(CtxResource(Mutex::new(ctx))).encode(env))
}

fn do_resolve(ctx: &mut Ctx) {
    let mut new_resolved = HashSet::new();
    for builtin in ctx.builtins.iter() {
        ctx.unresolved.remove(builtin);
        ctx.resolved.insert(builtin.clone());
    }
    loop {
        for unresolved in ctx.unresolved.iter() {
            if let Some(module) = ctx.modules.get(&unresolved.module) {
                if module.functions.contains_key(unresolved) {
                    new_resolved.insert(unresolved.clone());
                }
            }
        }
        if new_resolved.is_empty() {
            break;
        }
        for resolved in new_resolved.drain() {
            let mut all_calls = ctx
                .modules[&resolved.module]
                .functions[&resolved]
                .get_all_static_calls();
            println!("Calls for {}: {:?}", resolved, all_calls);
            for call in all_calls.drain(..) {
                if !ctx.resolved.contains(&call) {
                    ctx.unresolved.insert(call);
                }
            }
            ctx.unresolved.remove(&resolved);
            ctx.resolved.insert(resolved);
        }
    }
}

fn ctx_add_module<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let ctx_res: ResourceArc<CtxResource>  = args[0].decode()?;
    let text: String = args[1].decode()?;

    // We should probably move over to something like segmented stacks for the compiler.
    // For now, we just use a really large stack. This is very temporary TODO
    let join_handle: std::thread::JoinHandle<_> = Builder::new()
        .stack_size(16 * 1024 * 1024)
        .spawn(move || {
            let res = core_erlang_compiler::parser::parse(&text).unwrap();
            let module = core_erlang_compiler::ir::from_parsed(&res.0);
            let cps = cps_transform::transform_module(&module);
            cps
        }).unwrap();
    let result = join_handle.join().unwrap();

    let name = result.name.as_str().to_string();

    let mut ctx = ctx_res.0.lock().unwrap();

    ctx.modules.insert(result.name.clone(), result);
    do_resolve(&mut *ctx);

    Ok((atoms::ok(), name).encode(env))
}

#[derive(NifTuple)]
struct NFunctionName {
    module: Atom,
    name: Atom,
    arity: usize,
}

fn decode_fun_list<'a>(env: Env<'a>, term: Term<'a>) -> NifResult<Vec<FunctionIdent>> {
    let functions: Vec<NFunctionName> = term.decode()?;
    let ret = functions.iter()
        .map(|fun| FunctionIdent {
            module: EirAtom::from_str(&fun.module.to_term(env).atom_to_string().ok().unwrap()),
            name: EirAtom::from_str(&fun.name.to_term(env).atom_to_string().ok().unwrap()),
            arity: fun.arity,
            lambda: None,
        })
        .collect();
    Ok(ret)
}

fn ctx_add_root_functions<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let ctx_res: ResourceArc<CtxResource>  = args[0].decode()?;
    let functions = decode_fun_list(env, args[1])?;

    let mut ctx = ctx_res.0.lock().unwrap();

    for fun in functions.iter() {
        ctx.unresolved.insert(fun.clone());
    }

    do_resolve(&mut *ctx);

    println!("Unresolved: {:?}", ctx.unresolved);
    println!("Resolved: {:?}", ctx.resolved);

    Ok(atoms::ok().encode(env))
}

fn ctx_add_builtins<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let ctx_res: ResourceArc<CtxResource>  = args[0].decode()?;
    let mut functions = decode_fun_list(env, args[1])?;

    let mut ctx = ctx_res.0.lock().unwrap();

    for fun in functions.drain(..) {
        ctx.builtins.insert(fun);
    }
    do_resolve(&mut *ctx);

    Ok(atoms::ok().encode(env))
}

fn ctx_query_required_modules<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let ctx_res: ResourceArc<CtxResource>  = args[0].decode()?;
    let ctx = ctx_res.0.lock().unwrap();

    let mut modules = HashSet::new();
    for unresolved in ctx.unresolved.iter() {
        modules.insert(unresolved.module.clone());
    }

    let mut modules_vec: Vec<Term> = Vec::new();
    for module in modules.iter() {
        modules_vec.push(module.as_str().encode(env));
    }

    Ok((atoms::ok(), modules_vec).encode(env))
}

fn ctx_compile_module_nifs<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let ctx_res: ResourceArc<CtxResource>  = args[0].decode()?;
    let exported_functions = decode_fun_list(env, args[1])?;
    assert!(exported_functions.len() > 0);

    let ctx = ctx_res.0.lock().unwrap();
    if !ctx.unresolved.is_empty() {
        println!("There must be no unresolved modules/functions:");
        for unresolved in ctx.unresolved.iter() {
            println!(" * {}", unresolved);
        }
        panic!();
    }

    let mod_name = exported_functions[0].module.clone();
    for fun in exported_functions.iter() { assert!(fun.module == mod_name); }

    let mut context = CompilationContext::new("nif");

    //let mut envs = ctx.modules[&mod_name].envs.clone();
    //let mut cps_transformed = HashMap::new();

    // Generate native code for all functions
    for fun in ctx.resolved.iter() {
        context.gen_proto(fun);
    }

    for fun in ctx.resolved.iter() {
        if ctx.builtins.contains(fun) {
            continue;
        }
        println!("AA: {} {:?}", fun, ctx.modules.keys());
        //let module = if let Some(cps) = cps_transformed.get(&fun.module) {
        //    cps
        //} else {
        //    let module = &ctx.modules[&fun.module];
        //    let cps_module = ::cps_transform::transform_module(module);
        //    cps_transformed.insert(cps_module.name.clone(), cps_module);
        //    &cps_transformed[&fun.module]
        //};
        let module = &ctx.modules[&fun.module];
        context.build_function(module, fun.name.as_str(), fun.arity);
    }

    // Generate NIF definition code
    {
        let (data, target) = context.inner_mut();
        let module = &ctx.modules[&mod_name];
        target.gen_export(data, module, &exported_functions);
    }

    let path = Path::new("module.bc");
    context.write_bitcode(&path);

    //gen_nif::gen_module(&ctx.modules[&mod_name], &functions);

    Ok((atoms::ok()).encode(env))
}
