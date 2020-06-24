load("@obazl//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("@obazl//ocaml/private:actions/ocamlopt.bzl",
     "compile_native_with_ppx",
     "link_native")
load("@obazl//ocaml/private:actions/ppx.bzl",
     "apply_ppx",
     # "ocaml_ppx_compile",
     # # "ocaml_ppx_apply",
     # "ocaml_ppx_library_gendeps",
     # "ocaml_ppx_library_cmo",
     # "ocaml_ppx_library_link"
)
load("@obazl//ocaml/private:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "split_srcs",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

# print("private/ocaml.bzl loading")

################################################################
#### compile after preprocessing:
def _ocaml_ppx_library_with_ppx_impl(ctx):
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  if ctx.attr.preprocessor:
    if PpxInfo in ctx.attr.preprocessor:
      new_intf_srcs, new_impl_srcs = apply_ppx(ctx, env)
  else:
    new_intf_srcs, new_impl_srcs = split_srcs(ctx.files.srcs)

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  #################################################
  outfiles_cmi, outfiles_cmx, outfiles_o = compile_native_with_ppx(
    ctx, env, tc, new_intf_srcs, new_impl_srcs
  )

  # #################################################
  # ## 5. Link .cmxa
  # outfiles_cmi, outfiles_cmx, outfiles_o = link_native(
  #   ctx, env, tc, new_intf_srcs, new_impl_srcs
  # )

  outfile_cmxa_name = ctx.label.name + ".cmxa"
  outfile_cmxa = ctx.actions.declare_file(outfile_cmxa_name)
  outfile_a_name = ctx.label.name + ".a"
  outfile_a = ctx.actions.declare_file(outfile_a_name)
  args = ctx.actions.args()
  # args.add("ocamlopt")
  args.add("-w", WARNING_FLAGS)
  args.add("-strict-sequence")
  args.add("-strict-formats")
  args.add("-short-paths")
  args.add("-keep-locs")
  args.add("-g")
  args.add("-a")

  # args.add("-linkpkg")
  # args.add_all([dep[OpamPkgInfo].pkg for dep in ctx.attr.deps],
  #              before_each ="-package")
  # for dep in ctx.attr.deps:
  #   if OpamPkgInfo in dep:
  #     args.add("-package", dep[OpamPkgInfo].pkg)
  #   else:
  #     args.add(dep[PpxInfo].cmx)

  args.add("-o", outfile_cmxa)

  args.add("-linkall")
  args.add_all(outfiles_cmx)
  # args.add_all(outfiles_o)
  #################################################
  # ocaml_ppx_library_link(ctx,
  #                        env = env,
  #                        pgm = tc.ocamlopt,
  #                        # pgm = tc.ocamlfind,
  #                        args = [args],
  #                        inputs = outfiles_cmx + outfiles_o,
  #                        outputs = [outfile_cmxa, outfile_a],
  #                        tools = [tc.ocamlfind, tc.ocamlc],
  #                        msg = ctx.attr.message
  # )
  ctx.actions.run(
    env = env,
    executable = tc.ocamlopt,
    arguments = [args],
    inputs = outfiles_cmx + outfiles_o,
    outputs = [outfile_cmxa, outfile_a],
    tools = [tc.ocamlfind, tc.ocamlc],
    mnemonic = "OcamlPPXLibrary",
    progress_message = "ocaml_ppx_library({}): {}".format(
      ctx.label.name,
      ctx.attr.message,
      )
  )

  return [
    DefaultInfo(
    files = depset(direct = [#outfile_ppml,
                             #outfile_cmo,
                             # outfile_o,
                             # outfile_cmx,
                             outfile_a,
                             outfile_cmxa
    ])),
    PpxInfo(ppx=outfile_cmxa,
            # cmo=outfile_cmo,
            # cmx=outfile_cmx,
            cmxa=outfile_cmxa,
            a=outfile_a
    )]

#### just compile, no preprocessing:
def _ocaml_ppx_library_impl(ctx):
  ## this is essentially the same as ocaml_library, but it returns a
  ## ppx provider. should unify them?

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  ## task 1: declare outputs for each input source file

  # print("CTX.BINDIR: " + ctx.bin_dir.path)
  # print("CTX.BUILD_FILE_PATH: " + ctx.build_file_path)

  ## task 2: construct command

  args = ctx.actions.args()
  args.add("ocamlopt")
  args.add("-verbose")
  args.add("-w", ctx.attr.warnings)

  # Error (warning 49): no cmi file was found in path for module <m>
  # Disable for wrapper generation:
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

  args.add_all(ctx.attr.copts)

  build_deps = []
  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args.add("-package", dep[OpamPkgInfo].pkg)
    else:
      for g in dep[DefaultInfo].files.to_list():
        # if g.path.endswith(".cmi"):
        #   build_deps.append(g)
        if g.path.endswith(".cmx"):
          build_deps.append(g)
          args.add("-I", g.dirname)
        # if g.path.endswith(".o"):
        #   build_deps.append(g)
        # if g.path.endswith(".cmxa"):
        #   build_deps.append(g)
        #   args.add(g) # dep[DefaultInfo].files)
        # else:
        #   args.add(g) # dep[DefaultInfo].files)

  # args.add("-no-alias-deps")
  # args.add("-opaque")

  ## IMPORTANT!  from the ocamlopt docs:
  ## -o exec-file   Specify the name of the output file produced by the linker.
  ## That covers both executables and library archives (-a).
  ## If you're just compiling (-c), no need to pass -o.
  ## By contrast, the output files must be listed in the action output arg
  ## in order to be registered in the action dependency graph.

  # if "-a" in ctx.attr.copts:
  args.add_all(build_deps)
  # print("DEPS")
  # print(build_deps)

  ## WARNING: declare_file is relative to the BUILD.bazel dir, so if
  ## we're compiling generated files in a new directory, we have to
  ## account for that in declare_file.  The compiler puts output in
  ## the same dir as input.

  obj_files = []
  if "-c" in ctx.attr.copts:
    for src_f in ctx.files.srcs:
      # print("BNAME: " + src_f.basename)
      # print("SHORT: " + src_f.short_path)
      # print("ROOT: " + src_f.root.path)
      # print("TREEREL: " + src_f.tree_relative_path)
      # ocmi = ctx.actions.declare_file("_tmp_/" + src_f.basename.rstrip("ml") + "cmi")
      # obj_files.append(ocmi)
      # print("SRC: " + ocmi.path)
      obj_cmx = ctx.actions.declare_file(src_f.basename.rstrip("ml") + "cmx")
      obj_files.append(obj_cmx)
      obj_files.append(ctx.actions.declare_file(src_f.basename.rstrip("ml") + "o"))
      args.add(obj_cmx)
  else:
    ## declare an output for a lib archive:
    if "-a" in ctx.attr.copts:
      obj_cmxa = ctx.actions.declare_file(ctx.label.name + ".cmxa")
      ##Question: do we need to declare the .o file?
      # obj_a = ctx.actions.declare_file(ctx.label.name + ".a")
      obj_files.append(obj_cmxa)
      # obj_files.append(obj_a)
    else:
      if "-linkpkg" in ctx.attr.copts:
        obj_cmxa = ctx.actions.declare_file(ctx.label.name + ".cmxa")
        obj_files.append(obj_cmxa)

  # print("OBJ_FILES")
  # print(obj_files)


  if "-a" in ctx.attr.copts:
    # args.add("-open")
    # args.add("Ppx_snarky__Wrapper")
    args.add("-o", obj_cmxa)

  args.add_all(ctx.files.srcs)

  # args.add("-passrest")
  # args.add("-package", "ocaml-migrate-parsetree.driver-main")
  # args.add("-plugin")
  # args.add("migrate_parsetree_driver_main.cmxs")

  inputs_arg = ctx.files.srcs + build_deps
  # print("INPUT_ARGS:")
  # print(inputs_arg)

  outputs_arg = obj_files
  # print("OUTPUTS_ARG:")
  # print(outputs_arg)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs_arg,
    outputs = outputs_arg,
    tools = [tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlPpxLibrary",
    progress_message = "ocaml_ppx_library({}): {}".format(
        ctx.label.name, ctx.attr.message
      )
  )

  return [
    DefaultInfo(
    files = depset(direct = obj_files,
    )),
    PpxInfo(ppx=obj_files,
            # cmo=outfile_cmo,
            # cmx=outfile_cmx,
            # cmxa=obj_cmxa,
            # a=obj_a
    )]

#############################################
#### RULE DECL:  OCAML_PPX_LIBRARY  #########
ocaml_ppx_library = rule(
  implementation = _ocaml_ppx_library_impl,
  attrs = dict(
    preprocessor = attr.label(
      providers = [PpxInfo],
      executable = True,
      cfg = "exec",
      # allow_single_file = True
    ),
    message = attr.string(),
    dump_ast = attr.bool(default = True),
    srcs = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    # src_root = attr.label(
    #   allow_single_file = True,
    #   mandatory = True,
    # ),
    ####  OPTIONS  ####
    ##Flags. We set some flags by default; these params
    ## allow user to override.
    ## Problem is, this target registers two actions,
    ## compile and link, and each has its own params.
    ## for now, these affect the compile action:
    strict_sequence         = attr.bool(default = True),
    compile_strict_sequence = attr.bool(default = True),
    link_strict_sequence    = attr.bool(default = True),
    strict_formats          = attr.bool(default = True),
    short_paths             = attr.bool(default = True),
    keep_locs               = attr.bool(default = True),
    opaque                  = attr.bool(default = True),
    no_alias_deps           = attr.bool(default = True),
    debug                   = attr.bool(default = True),
    ## use these to pass additional args
    copts                   = attr.string_list(),
    linkopts                = attr.string_list(),
    warnings                = attr.string(
      default               = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"
    ),
    #### end options ####
    deps = attr.label_list(),
    mode = attr.string(default = "native"),
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    # outputs = attr.output_list(
    #   # default = ["%{name}.pp.ml",
    #   #           "%{name}.pp.ml.d"],
    # )
  ),
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl//ocaml:toolchain"],
  # outputs = { "build_dir": "_build_%{name}" },
)
