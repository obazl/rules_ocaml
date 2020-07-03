load("@obazl//ocaml/private:actions/ppx.bzl",
     "ocaml_ppx_library_compile")
load("@obazl//ocaml/private:providers.bzl", "OpamPkgInfo", "PpxInfo")
load("@obazl//ocaml/private:utils.bzl", "WARNING_FLAGS")

def _compile_native_intf(ctx, env, tc, f):
    outfile_cmi = ctx.actions.declare_file(f.basename.rstrip("mli") + "cmi")

def _compile_native_with_ppx_impl(ctx, env, tc, src_file):

    # src_files = []
    # for src_f in ctx.files.srcs:
    #     ctx.actions.declare_file(src_f.basename.rstrip("ml") + "cmi")
    #     ctx.actions.declare_file(src_f.basename.rstrip("ml") + "cmx")
    #     ctx.actions.declare_file(src_f.basename.rstrip("ml") + "cmo")


    obj_cmi = ctx.actions.declare_file(src_file.basename.rstrip("ml") + "cmi")
    obj_cmx = ctx.actions.declare_file(src_file.basename.rstrip("ml") + "cmx")
    # obj_cmo = ctx.actions.declare_file(src_file.basename.rstrip("ml") + "cmo")
    # obj_cmxa = ctx.actions.declare_file(src_file.basename.rstrip("ml") + "cmxa")
    obj_o   = ctx.actions.declare_file(src_file.basename.rstrip("ml") + "o")

    # if len(ctx.files.srcs) > 1:
    #     lib_cmx = ctx.actions.declare_file("ppx_version.cmx")

    args = ctx.actions.args()
    args.add("ocamlopt")
    # args.add("-verbose")
    args.add("-ccopt", "-v")
    args.add("-w", ctx.attr.warnings)

    # Error (warning 49): no cmi file was found in path for module <m>
    # Disable:
    args.add("-w", "-49")

    ## We pass a standard set of flags, which we ape from Dune:
    if ctx.attr.strict_sequence:
        args.add("-strict-sequence")
    if ctx.attr.strict_formats:
        args.add("-strict-formats")
    if ctx.attr.short_paths:
        args.add("-short-paths")
    if ctx.attr.keep_locs:
        args.add("-keep-locs")
    if ctx.attr.debug:
        args.add("-g")

    # args.add("-cclib")
    # args.add("-ljemalloc")

    # args.add("-linkpkg")
    # args.add("-linkall")

    # args.add("-i")  # generate .mli files

    # args.add("-open", "Ppx_version")

    # original sources:
    args.add("-I", ".")
    args.add("-I", "src/lib/ppx_version")
    # generated:
    args.add("-I", "bazel-out/darwin-fastbuild/bin/src/lib/ppx_version")

    ##NOTE: we must link pkgs, even though we are just compiling;
    ## otherwise we get "Unbounded module" errors.
    build_deps = []
    for dep in ctx.attr.deps:
        if OpamPkgInfo in dep:
            args.add("-package", dep[OpamPkgInfo].pkg)
        else:
            # if dep is ppx:
            # add to build_deps so we can pass to action inputs,
            # registering a dependency.
            for g in dep[DefaultInfo].files.to_list():
                if g.path.endswith(".cmx"):
                    build_deps.append(g)
                #     args.add(g) # dep[DefaultInfo].files)
                # else:
                #     args.add(g) # dep[DefaultInfo].files)

    # WARNING: including this causes search for mli file for intf, which fails
    # if len(ctx.files.srcs) > 1:
    #     args.add("-intf-suffix", ".ml")

    args.add("-no-alias-deps")
    args.add("-opaque")

    ## IMPORTANT!  from the ocamlopt docs:
    ## -o exec-file   Specify the name of the output file produced by the linker.
    ## That covers both executables and library archives (-a).
    ## If you're just compiling (-c), no need to pass -o.
    ## By contrast, the output files must be listed in the action output arg
    ## in order to be registered in the action dependency graph.

    if "-a" in ctx.attr.copts:
        args.add("-o", "foo")

    args.add_all(ctx.attr.copts)

    ## finally, pass the input source file:
    # if len(ctx.files.srcs) > 1:
    #     for s in ctx.files.srcs:
    #         args.add(s)
    # else:
    # args.add("-impl", src_file)
    args.add(src_file)

    print("BUILD_DEPS")
    print(build_deps)

    ins = ctx.files.srcs + build_deps
    print("SRC_FILE:")
    print(src_file.path)
    print("INs:")
    print(ins)

    if len(ctx.files.srcs) > 1:
        outs = [obj_cmi, obj_cmx, obj_o]
    else:
        outs = [obj_cmi, obj_cmx, obj_o]
    print("OUTS")
    print(outs)
    print("OUT_CMX")
    print(obj_cmx.path)

    ocaml_ppx_library_compile(ctx,
                              env = env,
                              pgm = tc.ocamlfind,
                              args = [args],
                              inputs = ins,
                              outputs = outs,
                              tools = [tc.ocamlfind, tc.ocamlopt],
                              msg = "compile_native_with_ppx_impl"
    )
    return obj_cmx, obj_o

def compile_native_with_ppx(ctx, env, tc, srcs_intf, srcs_impl):
    print("COMPILE_NATIVE")

    objs_cmi = []
    objs_cmx = []
    objs_cmxa = []
    objs_o = []

    # Step 1: generate .mli files
    # Step 2: compile .mli files to .cmi
    # Step 3: compile .ml files to .cmx

    for f in srcs_intf:
        objs_cmi.append(_compile_native_intf(ctx, env, tc, f))

    for f in srcs_impl:
        obj_cmx, obj_o = _compile_native_with_ppx_impl(ctx, env, tc, f)
        objs_cmx.append(obj_cmx)
        # objs_cmi.append(obj_cmi)
        objs_o.append(obj_o)
        # objs_cmxa.append(obj_cmxa)

    return objs_cmx, objs_o

################################################################
################################################################
################################################################
def link_native(ctx, env, tc, srcs_intf, srcs_impl):
    print("link_NATIVE")

    objs_cmi = []
    objs_cmx = []
    objs_o = []

    for f in srcs_intf:
        objs_cmi.append(_compile_native_intf(ctx, env, tc, f))

    for f in srcs_impl:
        obj_cmi, obj_cmx, obj_o = (_compile_native_with_ppx_impl(ctx, env, tc, f))
        objs_cmi.append(obj_cmi)
        objs_cmx.append(obj_cmx)
        objs_o.append(obj_o)

    return objs_cmi, objs_cmx, objs_o
