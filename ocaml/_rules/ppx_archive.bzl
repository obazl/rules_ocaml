load("@bazel_skylib//lib:collections.bzl", "collections")

load("//ocaml/_providers:ocaml.bzl", "OcamlSDK")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_providers:ppx.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")
# load("//implementation/actions:ocamlopt.bzl",
#      "compile_native_with_ppx",
#      "link_native")
# load("//implementation/actions:ppx.bzl",
#      "apply_ppx",
#      # "ocaml_ppx_compile",
#      # # "ocaml_ppx_apply",
#      # "ocaml_ppx_library_gendeps",
#      # "ocaml_ppx_library_cmo",
#      # "ocaml_ppx_library_link"
# )
load("//ocaml/_utils:deps.bzl", "get_all_deps")
load("//implementation:utils.bzl",
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

# print("implementation/ocaml.bzl loading")

tmpdir = "_obazl_/"

################################################################
#### Compile/link without preprocessing.
#### WARNING: this impl is sequential; it passes all source files to
#### one action, which will compile them (presumably in sequence) and
#### then link.
def _ppx_archive_impl(ctx):

  debug = False
  # if ctx.label.name == "ppx_version":
  #     debug = True

  mydeps = get_all_deps("ppx_archive", ctx)

  # print("PPX ARCHIVE MYDEPS")
  # print(mydeps.opam)

  # opam_lazy_deps = []
  # nopam_lazy_deps = []
  # for dep in ctx.attr.lazy_deps:
  #   if OpamPkgInfo in dep:
  #       opam_lazy_deps.append(dep)
  #   else:
  #       nopam_lazy_deps.append(dep)

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  ## declare outputs
  # obj_files = []

  if "-linkpkg" in ctx.attr.opts:
    fail("-linkpkg option not supported for ppx_archive rule")

  obj = {}
  if ctx.attr.archive_name:
    if ctx.attr.linkshared:
      obj["cmxs"] = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".cmxs")
    else:
      obj["cmxa"] = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".cmxa")
      obj["a"]    = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".a")
  else:
    if ctx.attr.linkshared:
      obj["cmxs"] = ctx.actions.declare_file(tmpdir + ctx.label.name + ".cmxs")
    else:
      obj["cmxa"] = ctx.actions.declare_file(tmpdir + ctx.label.name + ".cmxa")
      obj["a"]    = ctx.actions.declare_file(tmpdir + ctx.label.name + ".a")

  # print("PPX_ARCHIVE OBJS: %s" % obj)
  # obj_cmxa = ctx.actions.declare_file(outfile_cmxa_name)
  # obj_a    = ctx.actions.declare_file(outfile_a_name)

  args = ctx.actions.args()
  args.add("ocamlopt")
  # args.add_all(ctx.attr.flags)
  args.add_all(collections.uniq(ctx.attr.opts))

  if ctx.attr.linkall:
    args.add("-linkall")

  # NOTE: we do not put .a on the command line, since putting -o
  # foo.cmxa or -o foo.cmxs will automatically produce foo.a.
  # But we do add it to the Bazel outputs.
  if ctx.attr.linkshared:
    args.add("-shared")
    args.add("-o", obj["cmxs"])
  else:
    args.add("-a")
    args.add("-o", obj["cmxa"])

  ## We insert -I for each non-opam dep; since this would usually
  ## result in duplicates, we accumulate them first, then dedup.
  includes = []
  for dep in ctx.attr.deps:
    if not OpamPkgInfo in dep:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".cmx"):
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          includes.append(g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)

  #### WARNING!!! ####
  # For linking with redirector modules (module aliases), it is not
  # enough to add libs to the command line (by adding to args). They
  # must also be added to the 'inputs' parameter of the Bazel action;
  # if we don't do this, Bazel will not make them accessible, and we
  # will get 'Error: Unbound module'.  We use dep_graph to accum them.
  build_deps = []
  dep_graph  = []
  includes   = []

  for dep in mydeps.nopam.to_list():
    if debug:
          print("\nNOPAM DEP: %s\n\n" % dep)
    if dep.extension == "cmx":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.extension == "cmi":
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "mli":
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "o":
        # build_deps.append(dep)
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "cmxa":
        dep_graph.append(dep)
        includes.append(dep.dirname)
        ## "Option -a cannot be used with .cmxa input files."
        # build_deps.append(dep)
    elif dep.extension == "a":
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.extension == "so":
        if debug:
            print("NOPAM .so DEP: %s" % dep)
        dep_graph.append(dep)
        libname = dep.basename[:-3]
        libname = libname[3:]
        if debug:
          print("LIBNAME: %s" % libname)
        args.add("-ccopt", "-L" + dep.dirname)
        args.add("-cclib", "-l" + libname)
        # dso_deps.append(dep)
    elif dep.extension == "dylib":
        if debug:
            print("NOPAM .dylib DEP: %s" % dep)
        dep_graph.append(dep)
        libname = dep.basename[:-6]
        libname = libname[3:]
        if debug:
          print("LIBNAME: %s" % libname)
        args.add("-ccopt", "-L" + dep.dirname)
        args.add("-cclib", "-l" + libname)
        # includes.append(dep.dirname)
        # dso_deps.append(dep)
    else:
        if debug:
            print("NOMAP DEP not .cmx, ,cmxa, .o, .lo, .so, .dylib: %s" % dep.path)

  # for dep in ctx.attr.deps:
  #   if OpamPkgInfo in dep:
  #     args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
  #   else:
  #     for g in dep[DefaultInfo].files.to_list():
  #       # if g.path.endswith(".cmi"):
  #       #   build_deps.append(g)
  #       if g.path.endswith(".cmx"):
  #         includes.append(g.dirname)
  #         # build_deps.append(g)
  #         dep_graph.append(g)
  #       if g.path.endswith(".cmi"):
  #         includes.append(g.dirname)
  #         dep_graph.append(g)
  #       if g.path.endswith(".o"):
  #         includes.append(g.dirname)
  #         dep_graph.append(g)
  #       if g.path.endswith(".cmxa"):
  #         includes.append(g.dirname)
  #         ## cannot pass a cmxa dep when using -a
  #         # build_deps.append(g)
  #         dep_graph.append(g)

  # for an archive we need all deps on the command line:
  args.add_all(build_deps)

  # print("DEPS")
  # print(build_deps)

  args.add_all(includes, before_each="-I", uniquify = True)

  # args.add_all(ctx.files.srcs)

  # inputs_arg = ctx.files.srcs + build_deps
  # dep_graph.extend(ctx.files.srcs)

  # print("INPUT_ARGS:")
  # print(inputs_arg)

  # print("OUTPUTS_ARG:")
  # print(outputs_arg)
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = dep_graph,
    outputs = obj.values(), # outputs_arg,
    tools = [tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlPpxLibrary",
    progress_message = "ppx_archive({}): {}".format(
      ctx.label.name, ctx.attr.msg
    )
  )

  ppx_provider = PpxArchiveProvider(
      payload = struct(
          cmxa = obj["cmxa"] if "cmxa" in obj else None,
          cmxs = obj["cmxs"] if "cmxs" in obj else None,
          a    = obj["a"] if "a" in obj else None
          # cmi  : .cmi file produced by the target
          # cm   : .cmx or .cmo file produced by the target
          # o    : .o file produced by the target
      ),
      deps = struct(
          opam  = mydeps.opam,
          opam_lazy = mydeps.opam_lazy,
          nopam = mydeps.nopam,
          nopam_lazy = mydeps.nopam_lazy
      )
  )

  defaultInfo = DefaultInfo(
      files = depset(direct = obj.values()) # [obj_cmxa, obj_a])
  )

  result = [defaultInfo, ppx_provider]
  if debug:
      print("PpxArchiveProvider RESULT:")
      print(result)

  return result

#############################################
#### RULE DECL:  PPX_ARCHIVE  #########
ppx_archive = rule(
  implementation = _ppx_archive_impl,
  attrs = dict(
    archive_name = attr.string(),
    preprocessor = attr.label(
      providers = [PpxExecutableProvider],
      executable = True,
      cfg = "exec",
      # allow_single_file = True
    ),
    msg = attr.string(),
    dump_ast = attr.bool(default = True),
    # srcs = attr.label_list(
    #   allow_files = OCAML_FILETYPES
    # ),
    linkshared = attr.bool(default = False),
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
    linkall                 = attr.bool(default = False),
    ## use these to pass additional args
    opts                   = attr.string_list(),
    linkopts                = attr.string_list(),
    warnings                = attr.string(
      default               = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"
    ),
    #### end options ####
    deps = attr.label_list(
      providers = [[DefaultInfo], [PpxModuleProvider]]
    ),
    lazy_deps = attr.label_list(
      providers = [[DefaultInfo], [PpxModuleProvider]]
    ),
    mode = attr.string(default = "native"),
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    # outputs = attr.output_list(
    #   # default = ["%{name}.pp.ml",
    #   #           "%{name}.pp.ml.d"],
    # )
  ),
  provides = [DefaultInfo, PpxArchiveProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
  # outputs = { "build_dir": "_build_%{name}" },
)
