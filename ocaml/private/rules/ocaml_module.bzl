load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider",
     "OpamPkgInfo",
     "PpxArchiveProvider",
     "PpxBinaryProvider",
     "PpxModuleProvider")
load("//ocaml/private/actions:batch.bzl", "copy_srcs_to_tmp")
load("//ocaml/private/actions:module.bzl", "rename_module", "ppx_transform_action")
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

################################################################
########## RULE:  OCAML_MODULE  ################
def _ocaml_module_impl(ctx):

  mydeps = get_all_deps(ctx.attr.deps)
  # print("ALL DEPS for target %s" % ctx.label.name)
  # print(mydeps)

  # print("IMPL: %s" % ctx.file.impl.path)
  # srcs = copy_srcs_to_tmp(ctx)
  # print("SRCS: %s" % srcs)
  # impl_file = srcs[0]

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  secondary_deps = None
  if ctx.attr.ppx_bin:
    secondary_deps = ctx.attr.ppx_bin[PpxBinaryProvider].deps.secondary
    ## this will also handle ns
    outfile = ppx_transform_action("ocaml_module", ctx, ctx.file.impl)
  elif ctx.attr.ns:
    outfile = rename_module(ctx, ctx.attr.impl, ctx.attr.ns)
  else:
    outfile = ctx.file.impl

  # cmxfname = ctx.file.impl.basename.rstrip("ml") + "cmx"
  cmxfname = paths.replace_extension(outfile.basename, tc.objext)
  obj_cmx = ctx.actions.declare_file(cmxfname)
  ofname = paths.replace_extension(outfile.basename, ".o")
  obj_o = ctx.actions.declare_file(ofname)
  # cmxfname = paths.replace_extension(ctx.file.impl.basename, tc.objext)
  # obj_cmx = ctx.actions.declare_file(cmxfname)
  # ofname = paths.replace_extension(ctx.file.impl.basename, ".o")
  # obj_o = ctx.actions.declare_file(ofname)

  ################################################################
  args = ctx.actions.args()
  args.add(tc.compiler.basename)
  options = tc.opts + ctx.attr.opts
  args.add_all(options)

  # modules are always compile-only
  args.add("-c")

  # if ctx.attr.ns:
  #   args.add("-open", ctx.attr.ns)
  if ctx.attr.ns_module:
    args.add("-no-alias-deps")
    args.add("-opaque")
    ns_cm = ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm
    ns_mod = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
    args.add("-open", ns_mod)
    # capitalize_initial_char(ctx.attr.ppx_ns_module[PpxNsModuleProvider].payload.ns))

  args.add("-no-alias-deps")
  args.add("-opaque")

  if secondary_deps:
    args.add_all([dep for dep in secondary_deps], before_each="-package")

  inputs = []
  if ctx.attr.cmi:
    # print("CMI: %s" % ctx.attr.cmi[OcamlInterfaceProvider])
    inputs.append(ctx.file.cmi)
    args.add("-I", ctx.file.cmi.dirname)
  args.add("-I", obj_cmx.dirname)

  # if ctx.attr.ppx_libs:
  #   for item in ctx.attr.ppx.items():
  #     pkg = item[0].label.name
  #     print("PKG: {}".format(pkg))
  #     # args.add("-package", pkg)
  #     if item[1]:
  #       ppxargs = ",".join(item[1].split(" "))
  #       print("PPXARGS: {}".format(ppxargs))
  #       args.add("-ppxopt", pkg + "," + ppxargs)

  # args.add("-ppxopt", "ppx_jane,-annotated-ignores,-check-doc-comments,-dump-ast,--cookie,\'library-name=\"async_kernel\"\',-corrected-suffix,.ppx-corrected")


  args.add_all([dep.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  # we need to enumerate all build deps so we can add them to the
  # action inputs, and add a -I arg for them (we do not need to list
  # them as command line inputs, just the dirs where they can be found).
  build_deps = []
  includes   = []

  # intf_dep = None

  # print("XXXX DEPS for %s" % ctx.label.name)
  for dep in ctx.attr.deps:
    # print(dep)
    # if OpamPkgInfo in dep:
    #   g = dep[OpamPkgInfo].pkg.to_list()[0]
    #   args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
    # else:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".o"):
          build_deps.append(g)
          includes.append(g.dirname)
        # if g.path.endswith(".cmi"):
        #   intf_dep = g
        # #   build_deps.append(g)
        # #   includes.append(g.dirname)
        if g.path.endswith(".cmx"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxs"):
          includes.append(g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)

  args.add("-o", obj_cmx)

  args.add(outfile)

  inputs = inputs + build_deps + [outfile] #  [ctx.file.impl]  # ctx.files.impl
  # print("INPUTS:")
  # print(inputs)

  # cwd = paths.dirname(ctx.build_file_path)
  # print("CWD: %s" % cwd)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs,
    outputs = [obj_cmx, obj_o],
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlModule",
    progress_message = "ocaml_module({}), compiling impl {}".format(
      ctx.label.name, ctx.attr.msg
      )
  )

  module_provider = OcamlModuleProvider(
    payload = struct(
      # cmi = ctx.file.cmi if ctx.file.cmi else None,
      cmx = obj_cmx,
      o   = obj_o
    ),
    deps = struct(
      opam = mydeps.opam,
      nopam = mydeps.nopam
    )
  )

  return [
    DefaultInfo(files = depset(direct = [obj_cmx])),
    module_provider
  ]

#############################################
########## DECL:  OCAML_MODULE  ################
ocaml_module = rule(
  implementation = _ocaml_module_impl,
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
    impl = attr.label(
      mandatory = True,
      doc = "A single .ml source file label.",
      allow_single_file = OCAML_IMPL_FILETYPES
    ),
    cmi = attr.label(
      doc = "Single label of a target providing a single .cmi file (not a .mli source file). Optional",
      allow_single_file = [".cmi"],
      providers = [OcamlInterfaceProvider],
    ),
    ppx_bin  = attr.label(
      doc = "PPX binary (executable).",
      providers = [PpxBinaryProvider]
    ),
    ppx_bin_opts  = attr.string_list(
      doc = "Options to pass to PPX binary.",
    ),
    ppx = attr.label_keyed_string_dict(
      doc = """Dictionary of one entry. Key is a ppx target, val string is arguments."""
    ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlArchiveProvider],
                   [OcamlInterfaceProvider],
                   [OcamlLibraryProvider],
                   [OcamlModuleProvider],
                   [PpxArchiveProvider],
                   [PpxModuleProvider],
                   [CcInfo]],
    ),
    mode = attr.string(default = "native"),
    msg = attr.string(),
  ),
  provides = [OcamlModuleProvider],
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
