load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxBinaryProvider",
     "PpxModuleProvider")
load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")
load("//ocaml/private:utils.bzl",
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

#############################################
####  PPX_BINARY IMPLEMENTATION
def _ppx_binary_impl(ctx):

  dep_labels = [dep.label for dep in ctx.attr.deps]
  if Label("@opam//pkg:ppxlib.runner") in dep_labels:
    if not "-predicates" in ctx.attr.opts:
      print("""\n\nWARNING: target '{target}' depends on
'@opam//pkg:ppxlib.runner' but lacks -predicates option. PPX binaries that depend on this
usually pass \"-predicates\", \"ppx_driver\" to opts. Without this option, the binary may
compile but may not work as intended.\n\n""".format(target = ctx.label.name))
  else:
    print("""\n\nWARNING: ppx_binary target '{target}'
does not have a driver dependency.  Such targets usually depend on '@opam//pkg:ppxlib.runner'
or a similar PPX driver. Without a driver, the target may compile but not work as intended.\n\n""".format(target = ctx.label.name))

  # print("\n\nPPX BINARY ATTR.DEPS %s\n\n" % ctx.label.name)
  # print(ctx.attr.deps)

  mydeps = get_all_deps(ctx.attr.deps)

  # print("PPX BINARY OPAM DEPS")
  # print(mydeps.opam)
  # print("PPX BINARY NOPAM DEPS")
  # print(mydeps.nopam)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  outfilename = ctx.label.name
  outbinary = ctx.actions.declare_file(outfilename)

  args = ctx.actions.args()
  args.add("ocamlopt")
  options = tc.opts + ctx.attr.opts
  args.add_all(options)

  args.add("-o", outbinary)

  # for wrapper gen:
  # args.add("-w", "-24")

  build_deps = []
  includes = []

  # for dep in mydeps.opam.to_list():
  #   print("MYDEP: %s" % dep.to_list()[0].name)

  for dep in ctx.attr.deps:
    # if OpamPkgInfo in dep:
    #   args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
    #   # build_deps.append(dep[OpamPkgInfo].pkg)
    # else:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".cmx"):
          # args.add(g)
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          # args.add(g)
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

  # non-ocamlfind-enabled deps:
  args.add_all(build_deps)

  # print("\n\nTarget: {target}\nOPAM deps: {deps}\n\n".format(target=ctx.label.name, deps=mydeps.opam.to_list()))
  opam_deps = mydeps.opam.to_list()
  if len(opam_deps) > 0:
    # print("Linking OPAM deps for {target}".format(target=ctx.label.name))
    args.add("-linkpkg")
    args.add_all([dep.to_list()[0].name for dep in opam_deps], before_each="-package")

  # for ocamlfind-enabled deps, use -package
  # args.add_joined("-package", build_deps, join_with=",")

  # driver shim source must come after lib deps!
  args.add_all(ctx.files.srcs)

  inputs = build_deps + ctx.files.srcs
  # print("INPUTS:")
  # print(inputs)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs,
    outputs = [outbinary],
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlPPXBinary",
    progress_message = "ppx_binary({}), {}".format(
      ctx.label.name, ctx.attr.message
      )
  )

  secondary_deps = []
  for dep in ctx.attr.secondary_deps:
    # print("SEC DEP: %s" % dep[OpamPkgInfo])
    if OpamPkgInfo in dep:
      secondary_deps.append(dep[OpamPkgInfo].pkg.to_list()[0].name)
    #FIXME: also support non-opam secondary deps

  # print("PPX-BINARY SECONDARY: %s" % secondary_deps)

  return [DefaultInfo(executable=outbinary,
                      files = depset(direct = [outbinary])),
          PpxBinaryProvider(
            payload=outbinary,
            args = depset(direct = ctx.attr.args),
            deps = struct(
              opam = mydeps.opam,
              nopam = mydeps.nopam,
              secondary = secondary_deps
            )
          )]

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  PPX_BINARY  ################
ppx_binary = rule(
  implementation = _ppx_binary_impl,
  # implementation = _ppx_binary_compile_test,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    # IMPLICIT: args = string list = runtime args, passed whenever the binary is used
    srcs = attr.label_list(
      allow_files = OCAML_IMPL_FILETYPES
    ),
    ppx_bin  = attr.label(
      doc = "PPX binary (executable).",
      providers = [PpxBinaryProvider]
    ),
    ppx  = attr.label(
      doc = "PPX binary (executable).",
      providers = [PpxBinaryProvider]
    ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    deps = attr.label_list(
      providers = [[DefaultInfo], [PpxModuleProvider]]
    ),
    secondary_deps = attr.label_list(
      doc = """List of deps needed to compile sources after transformation. Dune calls these 'runtime' deps.""",
      # providers = [[DefaultInfo], [PpxModuleProvider]]
    ),
    mode = attr.string(default = "native"),
    message = attr.string()
  ),
  provides = [DefaultInfo, PpxBinaryProvider],
  executable = True,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
