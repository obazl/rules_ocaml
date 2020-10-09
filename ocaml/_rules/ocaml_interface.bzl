load("@bazel_skylib//lib:paths.bzl", "paths")
load("//implementation:providers.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider",
     "OpamPkgInfo",
     "PpxArchiveProvider",
     "PpxBinaryProvider")
load("//implementation/actions:module.bzl",
     "rename_ocaml_module",
     "ppx_transform_action")
load("//implementation/actions:ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")

load("//implementation:deps.bzl", "get_all_deps")

load("//implementation:utils.bzl",
     "capitalize_initial_char",
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

  debug = False
  # if (ctx.label.name == "IO.cmi"):
  #     debug = True

  if debug:
      print("OCAML INTERFACE TARGET: %s" % ctx.label.name)

  mydeps = get_all_deps("ocaml_interface", ctx) # ctx.attr.deps)
  # print("ALL DEPS for target %s" % ctx.label.name)
  # print(mydeps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  dep_graph = []

  intf_file = None
  opam_deps = []

  if ctx.attr.ppx:
    intf_file = ppx_transform_action("ocaml_interface", ctx, ctx.file.intf)
  elif ctx.attr.ns_module:
    intf_file = rename_ocaml_module(ctx, ctx.file.intf) #, ctx.attr.ns)
    # intf_file = rename_module(ctx, struct(impl = impl_src_file, intf = ctx.attr.intf), ctx.attr.ns)
  else:
    intf_file = ctx.file.intf
    # intf_file = struct(impl = impl_src_file, intf = ctx.attr.intf if ctx.attr.intf else None)


  # elif ctx.attr.ppx_libs:
  #   for item in ctx.attr.ppx.items():
  #     if item[0].label.workspace_name == "opam":
  #       args.add("-package", item[0].label.name)

  # cmifname = ctx.file.intf.basename.rstrip("mli") + "cmi"
  cmifname = intf_file.basename.rstrip("mli") + "cmi"
  obj_cmi = ctx.actions.declare_file(cmifname)

  args = ctx.actions.args()
  # args.add(tc.compiler.basename)
  args.add("ocamlc")
  # options = tc.opts + ctx.attr.opts
  # args.add_all(options)
  args.add_all(ctx.attr.opts)

  args.add("-c") # interfaces always compile-only?

  if ctx.attr.ns_module:
    # args.add("-no-alias-deps")
    # args.add("-opaque")
    ns_cm = ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm
    ns_mod = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
    args.add("-open", ns_mod)
    dep_graph.append(ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm)
    dep_graph.append(ctx.attr.ns_module[OcamlNsModuleProvider].payload.cmi)

    # capitalize_initial_char(ctx.attr.ns_module[PpxNsModuleProvider].payload.ns))

  # if ctx.attr.ns:
  #   args.add("-open", ctx.attr.ns)
  args.add("-I", obj_cmi.dirname)

  # args.add("-linkpkg")
  # args.add("-linkall")

  if ctx.attr.ppx:
    x_deps = ctx.attr.ppx[PpxBinaryProvider].deps.x
    for x_dep in x_deps.to_list():
        if OpamPkgInfo in x_dep:
            for x in x_dep[OpamPkgInfo].pkg.to_list():
                opam_deps.append(x.name)
        # else:
        #     ## FIXME: support nopam x_deps

  for dep in mydeps.opam.to_list():
      for x in dep.pkg.to_list():
          opam_deps.append(x.name)

  if len(opam_deps) > 0:
      args.add("-linkpkg")
      for dep in opam_deps:  # mydeps.opam.to_list():
          args.add("-package", dep)

  build_deps = []
  dso_deps = []
  includes   = []

  intf_dep = None

  for dep in mydeps.nopam.to_list():
    if debug:
        print("NOPAM DEP: %s" % dep)
        print("NOPAM DEP ext: %s" % dep.extension)
    if dep.extension == "cmx":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        # ocamlc chokes on cmx when building cmi
        # build_deps.append(dep)
    elif dep.extension == "cmi":
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "mli":
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "cmxa":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        # build_deps.append(dep)
        # for g in dep[OcamlArchiveProvider].deps.nopam.to_list():
        #     if g.path.endswith(".cmx"):
        #         includes.append(g.dirname)
        #         build_deps.append(g)
        #         dep_graph.append(g)
    elif dep.extension == "o":
        # build_deps.append(dep)
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "a":
        # build_deps.append(dep)
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "so":
        dso_deps.append(dep)
    else:
        if debug:
            print("NOMAP DEP not .cmx, ,cmxa, .o, .so: %s" % dep.path)

  # print("XXXX DEPS for %s" % ctx.label.name)
  for dep in ctx.attr.deps:
      if debug:
          print("DEP: %s" % dep)
      # if OpamPkgInfo in dep:
      #   g = dep[OpamPkgInfo].pkg.to_list()[0]
      #   args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
      # else:
      for g in dep[DefaultInfo].files.to_list():
          if debug:
              print("DEPFILE %s" % g)
          # print(g)
          # if g.path.endswith(".o"):
          #   dep_graph.append(g)
          #   includes.append(g.dirname)
          if g.path.endswith(".cmx"):
              dep_graph.append(g)
              includes.append(g.dirname)
          elif g.path.endswith(".cmxa"):
              dep_graph.append(g)
              includes.append(g.dirname)
              ## expose cmi files of deps for linking
              for h in dep[OcamlArchiveProvider].deps.nopam.to_list():
                  # print("LIBDEP: %s" % h)
                  if h.path.endswith(".cmx"):
                      dep_graph.append(h)
                      includes.append(h.dirname)
          elif g.path.endswith(".cmi"):
              intf_dep = g
              #   dep_graph.append(g)
              includes.append(g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)
  args.add_all(build_deps)

  args.add("-o", obj_cmi)

  # args.add(ctx.file.intf)
  args.add("-intf", intf_file)

  dep_graph.append(intf_file) #] + build_deps
  if ctx.attr.ns_module:
    dep_graph.append(ctx.attr.ns_module[OcamlNsModuleProvider].payload.cm)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = dep_graph,
    outputs = [obj_cmi],
    tools = [tc.ocamlopt],
    mnemonic = "OcamlModuleInterface",
    progress_message = "ocaml_interface {}".format(
        # ctx.label.name,
        ctx.attr.msg
      )
  )

  if debug:
      print("IF OUT: %s" % obj_cmi)

  interface_provider = OcamlInterfaceProvider(
    payload = struct(cmi = obj_cmi, mli = intf_file),
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
    module_name   = attr.string(
      doc = "Module name."
    ),
    # ns   = attr.string(
    #   doc = "Namespace string; will be used as module name prefix."
    # ),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__'",
      default = "__"
    ),
    ns_module = attr.label(
      doc = "Label of a ocaml_ns_module target. Used to derive namespace, output name, -open arg, etc.",
    ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    intf = attr.label(
      allow_single_file = OCAML_INTF_FILETYPES
    ),
    ppx  = attr.label(
      doc = "PPX binary (executable).",
      allow_single_file = True,
      providers = [PpxBinaryProvider]
    ),
    ppx_args  = attr.string_list(
      doc = "Options to pass to PPX binary.",
    ),
    ppx_deps  = attr.label_list(
        doc = "PPX dependencies. E.g. a file used by %%import from ppx_optcomp.",
        allow_files = True,
    ),
    # ppx = attr.label_keyed_string_dict(
    #   doc = """Dictionary of one entry. Key is a ppx target, val string is arguments."""
    # ),
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlArchiveProvider],
                   [OcamlLibraryProvider],
                   [PpxArchiveProvider],
                   [OcamlModuleProvider]]
    ),
    mode = attr.string(default = "native"),
    msg = attr.string(),
  ),
  provides = [OcamlInterfaceProvider],
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
