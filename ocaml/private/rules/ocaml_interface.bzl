load("@obazl_rules_ocaml//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OpamPkgInfo",
     "PpxInfo")
load("@obazl_rules_ocaml//ocaml/private:actions/ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")
load("@obazl_rules_ocaml//ocaml/private:utils.bzl",
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
def get_all_deps(deps):
  """Obtain the deps for a target and its transitive dependencies.

  Args:
    deps: a list of targets that are direct dependencies
  Returns:
    a depset listing all direct and indirect deps, opam and non-opam
  """

  opams = []
  transitive_opams = []
  nonopam_deps = []
  nonopam_transitive_deps = []
  for dep in deps:
    if OpamPkgInfo in dep:
      opams.append(dep[OpamPkgInfo].pkg)
    elif OcamlLibraryProvider in dep:
      d = dep[OcamlLibraryProvider]
      print("OcamlLibraryProovider deps: %s" % d)
      nonopam_deps.append(d)
      nonopam_transitive_deps.append(d)
    elif OcamlModuleProvider in dep:
      d = dep[OcamlModuleProvider]
      print("OcamlModuleProvider deps: %s" % d)
      nonopam_deps.append(d)
      nonopam_transitive_deps.append(d)
    else:
      fail("UNKNOWN DEP TYPE: %s" % dep)

  opam_deps = struct(
    direct     = opams,
    transitive = transitive_opams
  )
  nonopam_depset = depset(
    direct = nonopam_deps,
    # transitive = nonopam_transitive_deps
  )
  return [opam_deps, nonopam_depset]

########## RULE:  OCAML_INTERFACE  ################
def _ocaml_interface_impl(ctx):
  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  mydeps = get_all_deps(ctx.attr.deps)
  # print("ALL DEPS for target %s" % ctx.label.name)
  # print(mydeps)

  cmifname = ctx.file.intf.basename.rstrip("mli") + "cmi"
  obj_cmi = ctx.actions.declare_file(cmifname)

  args = ctx.actions.args()
  args.add_all(ctx.attr.opts)
  args.add("-c") # interfaces always compile-only?
  args.add("-o", obj_cmi)
  args.add(ctx.file.intf)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlopt,
    arguments = [args],
    inputs = [ctx.file.intf],
    outputs = [obj_cmi],
    tools = [tc.ocamlopt],
    mnemonic = "OcamlModuleInterface",
    progress_message = "ocaml_module({}), compiling interface {}".format(
      ctx.label.name, ctx.attr.message
      )
  )

  interface_provider = OcamlInterfaceProvider(
    interface = struct(cmi = obj_cmi),
    deps = struct(
      opam  = mydeps[0],
      nopam = mydeps[1]
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
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    srcs = attr.label_list(),
    impl = attr.label(
      allow_single_file = OCAML_IMPL_FILETYPES
    ),
    intf = attr.label(
      allow_single_file = OCAML_INTF_FILETYPES
    ),
    deps = attr.label_list(
      providers = [[OpamPkgInfo], [OcamlLibraryProvider], [OcamlModuleProvider]], # [OcamlInterfaceProvider]]
    ),
    mode = attr.string(default = "native"),
    message = attr.string(),
  ),
  provides = [OcamlInterfaceProvider],
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
