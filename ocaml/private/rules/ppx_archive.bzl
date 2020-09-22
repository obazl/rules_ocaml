load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxArchiveProvider",
     "PpxBinaryProvider",
     "PpxModuleProvider")
load("//ocaml/private/actions:ocamlopt.bzl",
     "compile_native_with_ppx",
     "link_native")
load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     # "ocaml_ppx_compile",
     # # "ocaml_ppx_apply",
     # "ocaml_ppx_library_gendeps",
     # "ocaml_ppx_library_cmo",
     # "ocaml_ppx_library_link"
)
load("//ocaml/private:utils.bzl",
     "xget_all_deps",
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
#### Compile/link without preprocessing.
#### WARNING: this impl is sequential; it passes all source files to
#### one action, which will compile them (presumably in sequence) and
#### then link.
def _ppx_archive_impl(ctx):

  ## this is essentially the same as ocaml_library, but it returns a
  ## ppx provider. should unify them?

  # print("_PPX_ARCHIVE_IMPL: %s" % ctx.label.name)
  if len(ctx.attr.deps) == 1:
    if PpxArchiveProvider in ctx.attr.deps[0]:
      ## used to redirect/wrap a ppx_module in another location
      ## e.g. src/ppx/register_event redirects to src/lib/ppx_register_event
      redirect = ctx.attr.deps[0]
      # print("PPX ARCHIVE REDIRECT: %s" % redirect)
      return [
        redirect[DefaultInfo],
        redirect[PpxArchiveProvider]
      ]

  mydeps = xget_all_deps(ctx.attr.deps)

  # print("PPX ARCHIVE MYDEPS")
  # print(mydeps.opam)

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
      obj["cmxs"] = ctx.actions.declare_file(ctx.attr.archive_name + ".cmxs")
    else:
      obj["cmxa"] = ctx.actions.declare_file(ctx.attr.archive_name + ".cmxa")
      obj["a"]    = ctx.actions.declare_file(ctx.attr.archive_name + ".a")
  else:
    if ctx.attr.linkshared:
      obj["cmxs"] = ctx.actions.declare_file(ctx.label.name + ".cmxs")
    else:
      obj["cmxa"] = ctx.actions.declare_file(ctx.label.name + ".cmxa")
      obj["a"]    = ctx.actions.declare_file(ctx.label.name + ".a")

  # print("PPX_ARCHIVE OBJS: %s" % obj)
  # obj_cmxa = ctx.actions.declare_file(outfile_cmxa_name)
  # obj_a    = ctx.actions.declare_file(outfile_a_name)

  args = ctx.actions.args()
  args.add("ocamlopt")
  args.add_all(ctx.attr.flags)
  args.add_all(ctx.attr.opts)

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

  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
    else:
      for g in dep[DefaultInfo].files.to_list():
        # if g.path.endswith(".cmi"):
        #   build_deps.append(g)
        if g.path.endswith(".cmx"):
          includes.append(g.dirname)
          build_deps.append(g)
          dep_graph.append(g)
        if g.path.endswith(".cmi"):
          includes.append(g.dirname)
          dep_graph.append(g)
        if g.path.endswith(".o"):
          includes.append(g.dirname)
          dep_graph.append(g)
        if g.path.endswith(".cmxa"):
          includes.append(g.dirname)
          build_deps.append(g)
          dep_graph.append(g)

  # for an archive we need all deps on the command line:
  args.add_all(build_deps)

  # print("DEPS")
  # print(build_deps)

  args.add_all(includes, before_each="-I", uniquify = True)

  args.add_all(ctx.files.srcs)

  inputs_arg = ctx.files.srcs + build_deps
  dep_graph.extend(ctx.files.srcs)

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

  return [
    DefaultInfo(
      files = depset(direct = obj.values()) # [obj_cmxa, obj_a])
    ),
    PpxArchiveProvider(
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
        nopam = mydeps.nopam
      )
    )
  ]

#############################################
#### RULE DECL:  PPX_ARCHIVE  #########
ppx_archive = rule(
  implementation = _ppx_archive_impl,
  attrs = dict(
    archive_name = attr.string(),
    preprocessor = attr.label(
      providers = [PpxBinaryProvider],
      executable = True,
      cfg = "exec",
      # allow_single_file = True
    ),
    msg = attr.string(),
    dump_ast = attr.bool(default = True),
    srcs = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    linkshared = attr.bool(default = False),
    # src_root = attr.label(
    #   allow_single_file = True,
    #   mandatory = True,
    # ),
    ####  OPTIONS  ####
    ##Flags. We set some flags by default; these params
    ## allow user to override.
    flags = attr.string_list(
      default = [
        "-strict-sequence",
        "-strict-formats",
        "-short-paths",
        "-keep-locs",
        "-g",
        "-no-alias-deps",
        "-opaque"
      ]
    ),
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
