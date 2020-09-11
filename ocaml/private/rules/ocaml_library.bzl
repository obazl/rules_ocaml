load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/private/actions:library.bzl", "library_action")
load("//ocaml/private/actions:ppx.bzl",     "ocaml_ppx_library_compile")
load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_link")
load("//ocaml/private/actions:batch.bzl", "copy_srcs_to_tmp")
load("//ocaml/private/actions:ocamlopt.bzl",
     "compile_native_with_ppx",
     "link_native")
load("//ocaml/private:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
# load("//ocaml/private:deps.bzl", "get_all_deps")
load("//ocaml/private:utils.bzl",
     # "xget_all_deps",
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
######## RULE DECL:  OCAML_LIBRARY  #########
##################################################
################################################################
def _ocaml_library_batch(ctx):
  # print("OCAML LIBRARY BATCH")

  return library_action(ctx)

################################################################
def _ocaml_library_parallel(ctx):
  print("OCAML LIBRARY PARALLEL")
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  args = ctx.actions.args()
  args.add(tc.compiler.basename)
  args.add_all(ctx.attr.opts)

  # if "-a" in ctx.attr.opts:
  #   args.add("-o", obj_cmxa)
  # else:
  #   args.add("-o", obj_cmx)

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

  includes = []

  args.add_all(ctx.attr.opts)

  ## Use case: srcs include paths. i.e. they're in subdirs of the pkg dir,
  ## In that case we want to include their dirs, that's where to output goes
  ## so we need to include them in case following files want to link
  ## input files could involve any number of subdirs, we need to add them all.
  ## Alternatively, we could -o all output files to one dir, but that would risk name clashes?
  bindir = ctx.bin_dir.path
  for src in ctx.files.srcs:
    includes.append(bindir + "/" + src.dirname)
  args.add("-I", bindir)
  args.add_all(includes, before_each="-I", uniquify = True)


  # compile each file separately
  out_files = []
  for src in ctx.files.srcs:
    if src.path.endswith("mli"):
      continue
    ## declare outputs
    obj_cmx = ctx.actions.declare_file(src.path.rstrip("ml") + tc.objext)
    obj_o = ctx.actions.declare_file(src.path.rstrip("ml") + "o")
    # obj_cmx = ctx.actions.declare_file(
    #   src.basename.rstrip("ml") + "cmx",
    #   sibling = src
    # )
    # obj_o = ctx.actions.declare_file(
    #   src.basename.rstrip("ml") + "o",
    #   sibling = src
    # )
    out_files.append(obj_cmx)
    out_files.append(obj_o)

    ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args, "-o", obj_cmx.path, src.path],
      inputs = [src],
      outputs = [obj_cmx, obj_o],
      tools = [tc.ocamlfind, tc.compiler],
      mnemonic = "OcamlLibrary",
      progress_message = "ocaml_library({}): {}".format(
        ctx.label.name, ctx.attr.msg
      )
    )


  return [
    DefaultInfo(
      files = depset(
        direct = out_files
      ))
  ]

################################################################
def _ocaml_library_impl(ctx):
  return _ocaml_library_batch(ctx)

  # obj_files = []
  # for f in ctx.files.srcs:
  #   obj_files.append(_ocaml_library_parallel(ctx, f))
  # return [
  #   DefaultInfo(
  #     files = depset(
  #       direct = obj_files
  #     ))
  # ]

################################################################
ocaml_library = rule(
  implementation = _ocaml_library_impl,
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
    depgraph = attr.label(
      allow_single_file = True,
    ),
    # src_root = attr.label(
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
    opts                   = attr.string_list(),
    linkopts                = attr.string_list(),
    warnings                = attr.string(
      default               = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"
    ),
    #### end options ####
    # lib = attr.bool(default = False)
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlArchiveProvider],
                   [OcamlInterfaceProvider],
                   [OcamlLibraryProvider],
                   [OcamlModuleProvider],
                   [OcamlNsModuleProvider],
                   [CcInfo]]
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
    _rule = attr.string(default = "ocaml_library")
  ),
  provides = [OcamlLibraryProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
  # outputs = { "build_dir": "_build_%{name}" },
)
