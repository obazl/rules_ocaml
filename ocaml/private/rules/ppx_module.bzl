load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "OcamlInterfaceProvider",
     "PpxBinaryProvider",
     "PpxNsModuleProvider",
     "PpxModuleProvider")
load("//ocaml/private/actions:batch.bzl", "copy_srcs_to_tmp")
load("//ocaml/private/actions:ns_module.bzl", "ns_module_action")
load("//ocaml/private/actions:module.bzl", "rename_module", "ppx_transform_action")
# load("//ocaml/private/actions:ppx.bzl",
     # "apply_ppx",
     # "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     # "ocaml_ppx_library_gendeps",
     # "ocaml_ppx_library_cmo",
     # "ocaml_ppx_library_compile",
     # "ocaml_ppx_library_link")
load("//ocaml/private:utils.bzl",
     "capitalize_initial_char",
     "get_all_deps",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "get_target_file",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

#############################################
####  OCAML_PPX_MODULE IMPLEMENTATION
def _ppx_module_impl(ctx):

  if not ctx.attr.impl:
    if len(ctx.attr.deps) == 1:
      ## used to redirect/wrap a ppx_module in another location
      ## e.g. src/ppx/register_event redirects to src/lib/ppx_register_event
      redirect = ctx.attr.deps[0]
      # print("PPX MODULE REDIRECT: %s" % redirect)
      return [
        redirect[DefaultInfo],
        redirect[PpxModuleProvider]
      ]

  mydeps = get_all_deps(ctx.attr.deps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  # if ctx.attr.ppx_ns_module:
  #   print("CTX.ATTR.PPX_NS_MODULE: %s" % ctx.attr.ppx_ns_module)
  #   print(" PpxNsModuleProvider: %s" % ctx.attr.ppx_ns_module[PpxNsModuleProvider])

  secondary_deps = None
  infile = None
  obj = {}
  if ctx.attr.ppx_bin:
    ## this will also handle ns
    infile = ppx_transform_action("ppx_module", ctx, ctx.file.impl)
    obj_cm = ctx.actions.declare_file(paths.replace_extension(infile.basename, ".cmx"))
    obj_o  = ctx.actions.declare_file(paths.replace_extension(infile.basename, ".o"))
    # srcs = ppx_transform_action("ppx_module", ctx, struct(impl = impl_src_file, intf = ctx.attr.intf))
    secondary_deps = ctx.attr.ppx_bin[PpxBinaryProvider].deps.secondary
  elif ctx.attr.ppx_ns_module:
    infile = rename_module(ctx, ctx.file.impl) # , ctx.attr.ns)
    obj_cm = ctx.actions.declare_file(paths.replace_extension(infile.basename, ".cmx"))
    obj_o  = ctx.actions.declare_file(paths.replace_extension(infile.basename, ".o"))
    outfile = paths.replace_extension(infile.basename, ".cmx")
    # srcs = rename_module(ctx, struct(impl = impl_src_file, intf = ctx.attr.intf), ctx.attr.ns)
  else:
    if ctx.attr.impl:
      infile = ctx.file.impl
      obj_cm = ctx.actions.declare_file(paths.replace_extension(infile.basename, ".cmx"))
      obj_o  = ctx.actions.declare_file(paths.replace_extension(infile.basename, ".o"))
      if ctx.attr.module_name:
        outfile = ctx.attr.module_name + ".cmx"
      else:
        outfile = paths.replace_extension(infile.basename, ".cmx")

  # print("SECONDARY DEPS: %s" % secondary_deps)

  # print("CTX.ATTR.IMPL: %s" % ctx.attr.impl)
  # print("CTX.ATTR.MODULE_NAME: %s" % ctx.attr.module_name)
  # print("INFILE: %s" % infile)
  # srcs now contains output files we need to declare, and we no longer need ns or ppx
  # srcs :: struct( impl :: declared File, maybe intf :: File )
  # Note that we need to declare the cmi output even if we do not have an intf input.

  obj = {}

  args = ctx.actions.args()
  args.add(tc.compiler.basename)
  args.add("-w", ctx.attr.warnings)
  options = tc.opts + ctx.attr.opts
  args.add_all(options)

  inputs = []

  if ctx.attr.ppx_ns_module:
    args.add("-no-alias-deps")
    args.add("-opaque")
    ns_cm = ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.cm
    inputs.append(ns_cm)
    ns_mod = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
    args.add("-open", ns_mod)
    # capitalize_initial_char(ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.ns))

  args.add("-c")
  args.add("-o", obj_cm)

  build_deps = []
  includes = []

  args.add("-I", obj_cm.dirname)

  ## transitive opam deps
  linkpkg_flag = False
  ##FIXME:  use mydeps.nopam
  for dep in ctx.attr.deps:
    # if OpamPkgInfo in dep:
    #   args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
    #   linkpkg_flag = True
    #   # build_deps.append(dep[OpamPkgInfo].pkg)
    # else:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".cmx"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          build_deps.append(g)
          includes.append(g.dirname)
  args.add_all(includes, before_each="-I", uniquify = True)

  # non-ocamlfind-enabled deps: we need to add to action inputs, but not to command args
  args.add_all(build_deps)

  if secondary_deps:
    args.add_all([dep for dep in secondary_deps], before_each="-package")

  inputs = inputs + build_deps + [infile] # [ctx.file.impl] #  [srcs.impl]
  if ctx.attr.cmi:
    # print("CMI: %s" % ctx.attr.cmi[OcamlInterfaceProvider])
    inputs.append(ctx.file.cmi)
    args.add("-I", ctx.file.cmi.dirname)

  # print("INPUTS:")
  # print(inputs)

  # if linkpkg_flag:
  args.add("-linkpkg")
  args.add_all([dep.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  args.add("-impl", outfile)
  args.add("-linkpkg")
  args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")


  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs,
    outputs = [obj_cm, obj_o],
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt] + ctx.files.data,
    mnemonic = "PpxModule",
    progress_message = "ppx_module({}), {}".format(
      ctx.label.name, ctx.attr.msg
      )
  )

  # print("srcs.impl: %s" % srcs.impl)
  # testing:
  return [
    DefaultInfo(files = depset(direct = [obj_cm, obj_o])),
    PpxModuleProvider(
      payload = struct(
        cmi = obj["cmi"] if "cmi" in obj else None,
        cm  = obj_cm,
        o   = obj_o
      ),
      deps = struct(
        opam  = mydeps.opam,
        nopam = mydeps.nopam
      )
    )
  ]

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  PPX_MODULE  ################
ppx_module = rule(
  implementation = _ppx_module_impl,
  # implementation = _ppx_module_compile_test,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    doc = attr.string(doc = "Docstring"),
    module_name = attr.string(
      doc = "Allows user to specify a module name different than the target name."
    ),
    ns   = attr.string(
      doc = "Namespace string; will be used as module name prefix."
    ),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__'",
      default = "__"
    ),
    ppx_ns_module = attr.label(
      doc = "Label of a ppx_ns_module target. Used to derive namespace, output name, -open arg, etc.",
    ),
    impl = attr.label(
      mandatory = True,  # use ocaml_interface for isolated .mli files
      doc = "A single .ml source file label.",
      allow_single_file = OCAML_IMPL_FILETYPES
    ),
    cmi = attr.label(
      doc = "Single label of a target providing a single .cmi file (not a .mli source file). Optional",
      allow_single_file = [".cmi"],
      providers = [OcamlInterfaceProvider],
    ),
    ppx = attr.label_keyed_string_dict(
      doc = """Dictionary of one entry. Key is a ppx target, val string is arguments.""",
      providers = [PpxBinaryProvider]
    ),
    ppx_bin  = attr.label(
      doc = "PPX binary (executable).",
      providers = [PpxBinaryProvider]
    ),
    ppx_bin_opts  = attr.string_list(
      doc = "Options to pass to PPX binary.  (E.g. [\"-cookie\", \"library-name=\\\"ppx_version\\\"\"]"
    ),
    args  = attr.string_list(
      doc = "PPX cmd args.",
    ),
    data  = attr.label_list(
      doc = "PPX data deps, e.g. headers",
      allow_files = True
    ),
    opts = attr.string_list(),
    warnings                = attr.string(
      default               = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"
    ),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    # srcs = attr.label_list(),
    deps = attr.label_list(
      # providers = [OpamPkgInfo]
    ),
    mode = attr.string(default = "native"),
    msg = attr.string()
  ),
  provides = [DefaultInfo, PpxModuleProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)

################################################################
################################################################
##########  PPX_NS_MODULE  ################
ppx_ns_module = rule(
  implementation = ns_module_action,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    module_name = attr.string(),
    ns = attr.string(),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__'",
      default = "__"
    ),
    submodules = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    opts = attr.string_list(
      default = [
        "-w", "-49", # ignore Warning 49: no cmi file was found in path for module x
        "-no-alias-deps", # lazy linking
        "-opaque"         #  do not generate cross-module optimization information
      ]
    ),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    mode = attr.string(default = "native"),
    msg = attr.string(),
    _rule = attr.string(default = "ppx_ns_module")
  ),
  provides = [DefaultInfo, PpxNsModuleProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)

