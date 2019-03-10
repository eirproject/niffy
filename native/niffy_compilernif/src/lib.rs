#[macro_use] extern crate rustler;
#[macro_use] extern crate rustler_codegen;
#[macro_use] extern crate lazy_static;

use rustler::{Env, Term, NifResult, Encoder, ResourceArc, Error};
use rustler::types::atom::Atom;
use rustler::schedule::SchedulerFlags;

use std::thread::Builder;
use std::sync::Mutex;
use std::collections::{ HashMap, HashSet };

use eir::{ Module, FunctionIdent };
use eir::Atom as EirAtom;

struct CtxResource(Mutex<Ctx>);

struct Ctx {
    modules: HashMap<EirAtom, Module>,
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
        ("add", 2, add),
        ("ctx_new", 0, ctx_new),
        ("ctx_add_module", 2, ctx_add_module, SchedulerFlags::DirtyCpu),
        ("ctx_query_required_modules", 2, ctx_query_required_modules),
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
    };
    Ok(ResourceArc::new(CtxResource(Mutex::new(ctx))).encode(env))
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
            module
        }).unwrap();
    let result = join_handle.join().unwrap();

    let name = result.name.as_str().to_string();

    let mut ctx = ctx_res.0.lock().unwrap();
    ctx.modules.insert(result.name.clone(), result);

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

fn ctx_query_required_modules<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let ctx_res: ResourceArc<CtxResource>  = args[0].decode()?;
    let functions = decode_fun_list(env, args[1])?;

    let ctx = ctx_res.0.lock().unwrap();

    let modules: Vec<Term> = functions.iter()
        .map(|ident| {
            if let Some(module) = ctx.modules.get(&ident.module) {
                Ok(module.functions[&ident].lir.get_all_calls())
            } else {
                Err(Error::RaiseTerm(Box::new(format!("Code for module {} not added", ident.module))))
            }
        })
        .collect::<NifResult<Vec<_>>>()?
        .drain(..)
        .flat_map(|v| v)
        .map(|id| id.module.as_str().encode(env))
        .collect();

    Ok((atoms::ok(), modules).encode(env))
}

fn ctx_compile_module_nifs<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let ctx_res: ResourceArc<CtxResource>  = args[0].decode()?;
    let functions = decode_fun_list(env, args[1])?;
    assert!(functions.len() > 0);

    let ctx = ctx_res.0.lock().unwrap();

    let mod_name = functions[0].module.clone();
    for fun in functions.iter() { assert!(fun.module == mod_name); }

    gen_nif::gen_module(&ctx.modules[&mod_name], &functions);

    Ok((atoms::ok()).encode(env))
}

fn add<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let num1: i64 = args[0].decode()?;
    let num2: i64 = args[1].decode()?;

    Ok((atoms::ok(), num1 + num2).encode(env))
}
