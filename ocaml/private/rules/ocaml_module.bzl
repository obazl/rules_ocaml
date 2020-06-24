load("@obazl//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OpamPkgInfo",
     "PpxInfo")
load("@obazl//ocaml/private:actions/ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")
load("@obazl//ocaml/private:utils.bzl",
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
def _compile_interface(ctx):

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  cmifname = ctx.file.intf.basename.rstrip("mli") + "cmi"
  obj_cmi = ctx.actions.declare_file(cmifname)

  args = ctx.actions.args()
  # args.add("-c")
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
  return [obj_cmi]

################################################################
def _compile_implementation(ctx):

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  args = ctx.actions.args()
  # we will pass ocamlfind as the exec arg, so we start args with ocamlopt
  args.add("ocamlopt")

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  args.add_all(ctx.attr.opts)
  # modules are always compile-only
  args.add("-c")

  # for wrapper gen:
  # args.add("-w", "-24")

  build_deps = []
  includes = []

  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
    else:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".o"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmx"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          build_deps.append(g)
          includes.append(g.dirname)
      # if PpxInfo in dep:
      #   print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
      #   build_deps.append(dep[PpxInfo].cmxa)
      #   build_deps.append(dep[PpxInfo].a)
      # else:
      #   print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
      #   for g in dep[DefaultInfo].files.to_list():
      #     print(g)
      #     if g.path.endswith(".cmx"):
      #       build_deps.append(g)
      #       args.add("-I", g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)

  # for ocamlfind-enabled deps, use -package
  # args.add_joined("-package", build_deps, join_with=",")

  # non-ocamlfind-enabled deps:
  args.add_all(build_deps)

  impl_file = ctx.file.impl
  cmxfname = ctx.file.impl.basename.rstrip("ml") + "cmx"
  obj_cmx = ctx.actions.declare_file(cmxfname)
  ofname = ctx.file.impl.basename.rstrip("ml") + "o"
  obj_o = ctx.actions.declare_file(ofname)

  ## Sibling arg can be used to ensure output will go to same
  ## dir as input.
  # if file is in same package as BUILD.bazel:
  #   obj_cmx = ctx.actions.declare_file(outfilename, sibling=ctx.file.impl)
  # else:

  args.add("-o", obj_cmx)

  args.add(impl_file)

  inputs = build_deps + ctx.files.impl
  # print("INPUTS:")
  # print(inputs)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs,
    outputs = [obj_cmx, obj_o],
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlPPXBinary",
    progress_message = "ocaml_module({}), {}".format(
      ctx.label.name, ctx.attr.message
      )
  )

  return [obj_cmx, obj_o]
  # return [DefaultInfo(files = depset(direct = [obj_cmx, obj_o]))]
# OutputGroupInfo(bin = depset([bin_output]))]

########## RULE:  OCAML_MODULE  ################
def _ocaml_module_impl(ctx):

  mydeps = get_all_deps(ctx.attr.deps)
  # print("ALL DEPS for target %s" % ctx.label.name)
  # print(mydeps)

  rintf = []
  rimpl = []
  if ctx.file.intf:
    rintf = _compile_interface(ctx)

  if ctx.file.impl:
    rimpl = _compile_implementation(ctx)

  module_provider = OcamlModuleProvider(
    module = struct(
      cmi = rintf,
      cmx = rimpl[0] if rimpl else None,
      o   = rimpl[1] if rimpl else None,
    ),
    deps = struct(
      opam  = mydeps.opam,
      nopam = mydeps.nopam
    )
  )
  # print("MODULE PROVIDER for {mod}: {mp}".format(mod=ctx.label.name, mp=module_provider))

  return [
    DefaultInfo(files = depset(direct = rimpl)),
    module_provider
  ]

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  OCAML_MODULE  ################
ocaml_module = rule(
  implementation = _ocaml_module_impl,
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
      providers = [[OpamPkgInfo],
                   [OcamlLibraryProvider], [OcamlModuleProvider],
                   # [OcamlInterfaceProvider]]
                   [CcInfo]],
    ),
    mode = attr.string(default = "native"),
    message = attr.string(),
  ),
  provides = [OcamlModuleProvider],
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl//ocaml:toolchain"],
)
