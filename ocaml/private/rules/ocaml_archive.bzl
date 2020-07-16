load("//ocaml/private:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("//ocaml/private:utils.bzl",
     "get_all_deps",
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
def _ocaml_archive_batch(ctx):
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  mydeps = get_all_deps(ctx.attr.deps)
  # print("ALL DEPS for target %s" % ctx.label.name)
  # print(mydeps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  ## declare outputs
  obj_files = []
  obj_cmxa = None
  obj_cmxs = None
  obj_a    = None
  if ctx.attr.archive_name:
    if ctx.attr.linkshared:
      obj_cmxs = ctx.actions.declare_file(ctx.attr.archive_name + ".cmxs")
    else:
      obj_cmxa = ctx.actions.declare_file(ctx.attr.archive_name + ".cmxa")
      # obj_a = ctx.actions.declare_file(ctx.attr.archive_name + ".a")
  else:
    if ctx.attr.linkshared:
      obj_cmxs = ctx.actions.declare_file(ctx.label.name + ".cmxs")
    else:
      obj_cmxa = ctx.actions.declare_file(ctx.label.name + ".cmxa")
      # obj_a = ctx.actions.declare_file(ctx.label.name + ".a")

  args = ctx.actions.args()
  args.add("ocamlopt")
  args.add("-w", ctx.attr.warnings)
  options = tc.opts + ctx.attr.opts
  # if ctx.attr.nocopts:
  args.add_all(options)
  if ctx.attr.linkshared:
    args.add("-shared")
    args.add("-o", obj_cmxs)
    obj_files.append(obj_cmxs)
  else:
    args.add("-a")
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

  build_deps = []  # for the command line
  includes = []
  inputs_arg = []  # for the run action inputs

  args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")
  # args.add_all([dep.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args.add("-package", dep[OpamPkgInfo].pkg)
    else:
      for g in dep[DefaultInfo].files.to_list():
        inputs_arg.append(g)
        includes.append(g.dirname)
        # exclude cmi deps, archives do not know what to do with them
        # if g.path.endswith(".cmi"):
        #   build_deps.append(g)
        if g.path.endswith(".cmx"):
          build_deps.append(g)
        elif g.path.endswith(".cmxa"):
          build_deps.append(g)
          # includes.append(g.dirname)
        elif g.path.endswith(".o"):
          build_deps.append(g)
        ## link a c lib
        elif g.extension == "a":
          # build_deps.append(g)
          ## -dllib is for bytecode only
          # args.add("-dllib", "lrakia")
          ## incredibly, starlark's rstrip function does not strip suffix strings. we have to hack it:
          libname = g.basename.rstrip("a")
          libname = libname.rstrip(".")
          libname = libname.lstrip("lib")
          args.add("-cclib", "-l" + libname)
        # elif g.path.endswith(".so"):
        #   build_deps.append(g)
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

  ## since we're building an archive, we need all members on command line
  args.add_all(build_deps)

  args.add_all(ctx.files.srcs)

  inputs_arg = inputs_arg + build_deps + ctx.files.srcs
  # print("INPUT_ARGS:")
  # print(inputs_arg)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs_arg,
    outputs = obj_files,
    tools = [tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlLibrary",
    progress_message = "ocaml_archive({}): {}".format(
        ctx.label.name, ctx.attr.msg
      )
  )

  ap = OcamlArchiveProvider(
    archive = struct(
      name = ctx.label.name,
      cmxa = obj_cmxa,
      cmxs = obj_cmxs,
      a    = obj_a
    ),
    deps = struct(
      opam = mydeps.opam,
      nopam = mydeps.nopam
    )
  )

  # print("ARCHIVEPROVIDER for {arch}: {ap}".format(arch=ctx.label.name, ap=ap))
  return [
    DefaultInfo(
      files = depset(
        direct = obj_files
      )),
    ap
  ]

################################################################
def _ocaml_archive_impl(ctx):
  return _ocaml_archive_batch(ctx)

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
  doc = """Generates an OCaml archive file (.cmxa) and a C archive file (.a).

  Here is an example, from the 'digestif' library:

ocaml_archive(
    name = "common_archive",
    msg = "digestif, common",
    opts = ["-I", "src", "-open", "Digestif_by"],
    deps = [
        ":digestif_by",
        ":digestif_bi",
        ":digestif_conv",
        ":digestif_eq",
        ":digestif_hash",
        ":digestif_mli", # this will be ignored, archives do not understand cmi files
    ]
)


""",
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
      doc = "OCaml source files",
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
    # strict_sequence         = attr.bool(default = True),
    # strict_formats          = attr.bool(default = True),
    # short_paths             = attr.bool(default = True),
    compile_strict_sequence = attr.bool(default = True),
    link_strict_sequence    = attr.bool(default = True),
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
    # nocopts = attr.string(),
    linkshared = attr.bool(default = False),
    #### end options ####
    # lib = attr.bool(default = False)
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlInterfaceProvider],
                   [OcamlModuleProvider], [OcamlNsModuleProvider],
                   [OcamlLibraryProvider], [OcamlArchiveProvider],
                   [CcInfo]],
    ),
    mode = attr.string(default = "native"),
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    msg = attr.string(),
    # outputs = attr.output_list(
    #   # default = ["%{name}.pp.ml",
    #   #           "%{name}.pp.ml.d"],
    # )
  ),
  provides = [OcamlArchiveProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
  # outputs = { "build_dir": "_build_%{name}" },
)
