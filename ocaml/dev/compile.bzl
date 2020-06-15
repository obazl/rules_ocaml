load("@obazl//ocaml/private:actions/ppx.bzl",
     "ocaml_ppx_library_compile")
load("@obazl//ocaml/private:actions/ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_link")
load("@obazl//ocaml/private:actions/ocamlopt.bzl",
     "compile_native_with_ppx",
     "link_native")
load("@obazl//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("@obazl//ocaml/private:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "split_srcs",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

##################################################
#### RULE DECL:  OCAML_COMPILE_WITH_PPX  #########
##################################################
def _ocaml_compile_with_ppx_impl(ctx):
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

  outfiles_cmx, outfiles_o = compile_native_with_ppx(
    ctx, env, tc, new_intf_srcs, new_impl_srcs
  )
  print("_ocaml_compile_with_ppx_impl outfiles_cmx")
  print(outfiles_cmx)
  print("_ocaml_compile_with_ppx_impl outfiles_o")
  print(outfiles_o)

  return [
    DefaultInfo(
    files = depset(
      direct = outfiles_cmx + outfiles_o,
                             # + outfiles_cmo,
    ))
  ]

################################################################
ocaml_compile_with_ppx = rule(
  implementation = _ocaml_compile_with_ppx_impl,
  attrs = dict(
    preprocessor = attr.label(
      providers = [PpxInfo],
      executable = True,
      cfg = "exec",
      # allow_single_file = True
    ),
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
    # lib = attr.bool(default = False)
    deps = attr.label_list(),
    mode = attr.string(default = "native"),
    _sdkpath = attr.label(
      default = Label("@ocaml_sdk//:path")
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

##################################################
######## RULE DECL:  OCAML_COMPILE  #########
##################################################
def _ocaml_compile_impl(ctx):
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  ## task 1: declare outputs for each input source file

  obj_files = []
  if "-c" in ctx.attr.copts:
    for src_f in ctx.files.srcs:
      obj_files.append(ctx.actions.declare_file(src_f.basename.rstrip("ml") + "cmi"))
      obj_files.append(ctx.actions.declare_file(src_f.basename.rstrip("ml") + "cmx"))
      obj_files.append(ctx.actions.declare_file(src_f.basename.rstrip("ml") + "o"))
  else:
    ## declare an output for a lib archive:
    if "-a" in ctx.attr.copts:
      obj_cmxa = ctx.actions.declare_file(ctx.label.name + ".cmxa")
      obj_files.append(obj_cmxa)
    else:
      obj_exec = ctx.actions.declare_file(ctx.label.name)
      obj_files.append(obj_exec)

  # print("OBJ_FILES")
  # print(obj_files)

  ## task 2: construct command

  args = ctx.actions.args()
  args.add("ocamlopt")
  # args.add("-verbose")
  # args.add("-ccopt", "-v")
  # args.add("-cclib", "-v")
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

  ## Dune uses these:
  # args.add("-cclib")
  # args.add("-ljemalloc")

  # args.add("-i")  # generate .mli files

  # args.add("-open", "Ppx_version")

  # print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
  # print(ctx.bin_dir.path) # bazel-out/host/bin
  # print(ctx.build_file_path) # bazel-out/host/bin
  # # original sources:
  # args.add("-I", "bazel-out/host/bin/src/lib/ppx_version")
  # args.add("-I", "src/lib/ppx_version")
  # # generated:
  # args.add("-I", obj
# "bazel-out/darwin-fastbuild/bin/src/lib/ppx_version")
  # args.add("-I", "bazel-bin/src/lib/ppx_version")

  ## we need to filter non-opam deps and add them to inputs,
  ## so that they are registered in the action dependency graph.
  # args.add("-linkpkg")
  # args.add("-linkall")

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

  args.add("-no-alias-deps")
  args.add("-opaque")

  ## IMPORTANT!  from the ocamlopt docs:
  ## -o exec-file   Specify the name of the output file produced by the linker.
  ## That covers both executables and library archives (-a).
  ## If you're just compiling (-c), no need to pass -o.
  ## By contrast, the output files must be listed in the action output arg
  ## in order to be registered in the action dependency graph.

  if "-c" not in ctx.attr.copts:
    args.add("-o", obj_exec)

  ## finally, pass the input source file:
  # if len(ctx.files.srcs) > 1:
  #     for s in ctx.files.srcs:
  #         args.add(s)
  # else:
  # args.add("-impl", src_file)

  # if "-a" in ctx.attr.copts:
  args.add_all(build_deps)

  args.add_all(ctx.attr.copts)

  args.add_all(ctx.files.srcs)

  inputs_arg = ctx.files.srcs + build_deps
  # print("INPUT_ARGS:")
  # print(inputs_arg)

  outputs_arg = obj_files
  # print("OUTPUTS_ARG:")
  # print(outputs_arg)

  ocaml_ppx_library_compile(ctx,
                            env = env,
                            pgm = tc.ocamlfind,
                            args = [args],
                            inputs = inputs_arg,
                            outputs = outputs_arg,
                            tools = [tc.ocamlfind, tc.ocamlopt],
                            msg = ctx.attr.message
  )

  return [
    DefaultInfo(
      files = depset(
        direct = obj_files
      ))
  ]

################################################################
ocaml_compile = rule(
  implementation = _ocaml_compile_impl,
  attrs = dict(
    preprocessor = attr.label(
      providers = [PpxInfo],
      executable = True,
      cfg = "exec",
      # allow_single_file = True
    ),
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
    # lib = attr.bool(default = False)
    deps = attr.label_list(),
    mode = attr.string(default = "native"),
    _sdkpath = attr.label(
      default = Label("@ocaml_sdk//:path")
    ),
    message = attr.string()
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
