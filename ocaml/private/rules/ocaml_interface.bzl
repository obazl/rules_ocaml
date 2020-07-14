load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider",
     "OpamPkgInfo",
     "PpxBinaryProvider")
load("//ocaml/private/actions:module.bzl",
     "rename_module",
     "ppx_transform_action")
load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")
load("//ocaml/private:utils.bzl",
     "capitalize_initial_char",
     "get_all_deps",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

########## RULE:  OCAML_INTERFACE  ################
def _ocaml_interface_impl(ctx):

  mydeps = get_all_deps(ctx.attr.deps)
  # print("ALL DEPS for target %s" % ctx.label.name)
  # print(mydeps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  outfile = None
  secondary_deps = None
  if ctx.attr.ppx_bin:
    # secondary_deps = [dep for dep in ctx.attr.ppx_bin[PpxBinaryProvider].deps.secondary]
    secondary_deps = ctx.attr.ppx_bin[PpxBinaryProvider].deps.secondary
    # print("INTERFACE ppx: %s" % secondary_deps)
    outfile = ppx_transform_action("ocaml_interface", ctx, ctx.file.intf)
  elif ctx.attr.ns:
    outfile = rename_module(ctx, ctx.attr.intf, ctx.attr.ns)
    # outfile = rename_module(ctx, struct(impl = impl_src_file, intf = ctx.attr.intf), ctx.attr.ns)
  else:
    outfile = ctx.file.intf
    # outfile = struct(impl = impl_src_file, intf = ctx.attr.intf if ctx.attr.intf else None)


  # elif ctx.attr.ppx_libs:
  #   for item in ctx.attr.ppx.items():
  #     if item[0].label.workspace_name == "opam":
  #       args.add("-package", item[0].label.name)

  # cmifname = ctx.file.intf.basename.rstrip("mli") + "cmi"
  cmifname = outfile.basename.rstrip("mli") + "cmi"
  obj_cmi = ctx.actions.declare_file(cmifname)

  args = ctx.actions.args()
  # args.add(tc.compiler.basename)
  args.add("ocamlc")
  options = tc.opts + ctx.attr.opts
  args.add_all(options)

  args.add("-c") # interfaces always compile-only?

  if ctx.attr.ns_module:
    # args.add("-no-alias-deps")
    # args.add("-opaque")
    ns_cm = ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm
    ns_mod = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
    args.add("-open", ns_mod)
    # capitalize_initial_char(ctx.attr.ns_module[PpxNsModuleProvider].payload.ns))

  # if ctx.attr.ns:
  #   args.add("-open", ctx.attr.ns)
  args.add("-I", obj_cmi.dirname)

  # args.add("-linkpkg")
  # args.add("-linkall")
  args.add_all([dep.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  if secondary_deps:
    args.add_all([dep for dep in secondary_deps], before_each="-package")

  build_deps = []
  includes   = []

  intf_dep = None

  # print("XXXX DEPS for %s" % ctx.label.name)
  for dep in ctx.attr.deps:
    # print(dep)
    # if OpamPkgInfo in dep:
    #   g = dep[OpamPkgInfo].pkg.to_list()[0]
    #   args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
    # else:
      for g in dep[DefaultInfo].files.to_list():
        # print(g)
        if g.path.endswith(".o"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmi"):
          intf_dep = g
        #   build_deps.append(g)
        #   includes.append(g.dirname)
        if g.path.endswith(".cmx"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          build_deps.append(g)
          includes.append(g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)
  # args.add_all(build_deps)

  args.add("-o", obj_cmi)

  # args.add(ctx.file.intf)
  args.add("-intf", outfile)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = [outfile] + build_deps,
    # inputs = [ctx.file.intf] + build_deps,
    outputs = [obj_cmi],
    tools = [tc.ocamlopt],
    mnemonic = "OcamlModuleInterface",
    progress_message = "ocaml_interface({}), {}".format(
      ctx.label.name, ctx.attr.msg
      )
  )

  interface_provider = OcamlInterfaceProvider(
    payload = struct(cmi = obj_cmi),
    deps = struct(
      opam  = mydeps.opam,
      nopam = mydeps.nopam
    )
  )

  return [DefaultInfo(files = depset(direct = [obj_cmi])),
          interface_provider]

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  OCAML_INTERFACE  ################
ocaml_interface = rule(
  implementation = _ocaml_interface_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    ns   = attr.string(
      doc = "Namespace string; will be used as module name prefix."
    ),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__'",
      default = "__"
    ),
    ns_module = attr.label(
      doc = "Label of a ppx_ns_module target. Used to derive namespace, output name, -open arg, etc.",
    ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    intf = attr.label(
      allow_single_file = OCAML_INTF_FILETYPES
    ),
    ppx_bin  = attr.label(
      doc = "PPX binary (executable).",
      allow_single_file = True,
      providers = [PpxBinaryProvider]
    ),
    ppx_bin_opts  = attr.string_list(
      doc = "Options to pass to PPX binary.",
    ),
    ppx = attr.label_keyed_string_dict(
      doc = """Dictionary of one entry. Key is a ppx target, val string is arguments."""
    ),
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlArchiveProvider],
                   [OcamlLibraryProvider],
                   [OcamlModuleProvider]], # [OcamlInterfaceProvider]]
    ),
    mode = attr.string(default = "native"),
    msg = attr.string(),
  ),
  provides = [OcamlInterfaceProvider],
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
