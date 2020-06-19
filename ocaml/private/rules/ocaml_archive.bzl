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
######## RULE DECL:  OCAML_ARCHIVE  #########
#  Build .cmxa, .a
##################################################
def _ocaml_archive_sequential(ctx):
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  args = ctx.actions.args()
  args.add("ocamlopt")
  args.add("-a")
  args.add_all(ctx.attr.opts)

  ## declare outputs
  obj_files = []
  if "-c" in ctx.attr.opts:
    fail("-c option imcompatible with ocaml_archive target.")


  if ctx.attr.archive_name:
    obj_cmxa = ctx.actions.declare_file(ctx.attr.archive_name + ".cmxa")
  else:
    obj_cmxa = ctx.actions.declare_file(ctx.label.name + ".cmxa")

  args.add("-o", obj_cmxa)
  obj_files.append(obj_cmxa)

  ## We also need to add the .o files as outputs. Why? Because -
  ## assuming we use lazy linking - a change to a source file that
  ## does not affect an interface will not result in a change to the
  ## cmxa file, so downstream targets that depend only on cmxa will
  ## not rebuilt. So we need the dependency to be on both the cmxa and
  ## the associated object files.
  for src in ctx.files.srcs:
    if src.path.endswith(".ml"):
      obj_files.append(ctx.actions.declare_file(src.basename.rstrip(".ml") + ".o"))

  # print("OBJ_FILES")
  # print(obj_files)


  build_deps = []
  includes = []
  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args.add("-package", dep[OpamPkgInfo].pkg)
    else:
      for g in dep[DefaultInfo].files.to_list():
        # if g.path.endswith(".cmi"):
        #   build_deps.append(g)
        if g.path.endswith(".cmx"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          build_deps.append(g)
          includes.append(g.dirname)
        # if g.path.endswith(".o"):
        #   build_deps.append(g)
        # if g.path.endswith(".cmxa"):
        #   build_deps.append(g)
        #   args.add(g) # dep[DefaultInfo].files)
        # else:
        #   args.add(g) # dep[DefaultInfo].files)

  args.add_all(includes, before_each="-I", uniquify = True)

  # WARNING: including this causes search for mli file for intf, which fails
  # if len(ctx.files.srcs) > 1:
  #     args.add("-intf-suffix", ".ml")

  # args.add("-no-alias-deps")
  # args.add("-opaque")

  ## IMPORTANT!  from the ocamlopt docs:
  ## -o exec-file   Specify the name of the output file produced by the linker.
  ## That covers both executables and library archives (-a).
  ## If you're just compiling (-c), no need to pass -o.
  ## By contrast, the output files must be listed in the action output arg
  ## in order to be registered in the action dependency graph.

  ## finally, pass the input source file:
  # if len(ctx.files.srcs) > 1:
  #     for s in ctx.files.srcs:
  #         args.add(s)
  # else:
  # args.add("-impl", src_file)

  # if "-a" in ctx.attr.opts:
  args.add_all(build_deps)
  # print("DEPS")
  # print(build_deps)

  args.add_all(ctx.files.srcs)

  # args.add("-passrest")
  # args.add("-package", "ocaml-migrate-parsetree.driver-main")
  # args.add("-plugin")
  # args.add("migrate_parsetree_driver_main.cmxs")

  inputs_arg = ctx.files.srcs + build_deps
  # print("INPUT_ARGS:")
  # print(inputs_arg)

  outputs_arg = obj_files + build_deps
  # print("OUTPUTS_ARG:")
  # print(outputs_arg)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs_arg,
    outputs = outputs_arg,
    tools = [tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlLibrary",
    progress_message = "ocaml_archive({}): {}".format(
        ctx.label.name, ctx.attr.message
      )
  )


  return [
    DefaultInfo(
      files = depset(
        direct = outputs_arg # obj_files
      ))
  ]

################################################################
def _ocaml_archive_impl(ctx):
  return _ocaml_archive_sequential(ctx)

  # obj_files = []
  # for f in ctx.files.srcs:
  #   obj_files.append(_ocaml_archive_parallel(ctx, f))
  # return [
  #   DefaultInfo(
  #     files = depset(
  #       direct = obj_files
  #     ))
  # ]

################################################################
ocaml_archive = rule(
  implementation = _ocaml_archive_impl,
  attrs = dict(
    archive_name = attr.string(),
    preprocessor = attr.label(
      providers = [PpxInfo],
      executable = True,
      cfg = "exec",
      # allow_single_file = True
    ),
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
    opts                    = attr.string_list(),
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
