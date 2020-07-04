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
# testing
load("//ocaml/private/actions:ocamlopt.bzl",
     "compile_native_with_ppx",
     "link_native")

# print("private/ocaml.bzl loading")

################################################################
# # for testing
# def split_srcs(srcs):
#   print("SPLIT_SRCS")
#   print(srcs)
#   intfs = []
#   impls = []
#   for s in srcs:
#     if s.extension == "ml":
#       impls.append(s)
#     else:
#       intfs.append(s)
#   return intfs, impls

# def _ocaml_ppx_binary_compile_test(ctx):
#   print("TEST: _ocaml_ppx_binary_compile_impl")
#   env = {"OPAMROOT": get_opamroot(),
#          "PATH": get_sdkpath(ctx)}

#   if ctx.attr.ppx:  # preprocessor:
#     if PpxInfo in ctx.attr.preprocessor:
#       new_intf_srcs, new_impl_srcs = apply_ppx(ctx, env)
#   else:
#     new_intf_srcs, new_impl_srcs = split_srcs(ctx.files.srcs)

#   tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

#   lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

#   outfiles_cmx = []
#   outfiles_o = []
#   outfiles_cmi, outfiles_cmx, outfiles_o = compile_native_with_ppx(
#     ctx, env, tc, new_intf_srcs, new_impl_srcs
#   )

#   return [
#     DefaultInfo(
#       files = depset(direct = outfiles_o + outfiles_cmx)
#     ),
#     PpxBinaryProvider(
#       payload = struct(
#         name = ctx.label.name,
#         modules = ctx.attr.deps
#       ),
#       deps = struct(
#         opam = mydeps.opam,
#         nopam = mydeps.nopam
#       )
#     )
#       cmx=outfiles_cmx,
#       o = outfiles_o
#     )]

#############################################
####  PPX_BINARY IMPLEMENTATION
def _ppx_binary_impl(ctx):

  # print("PPX BINARY ATTR.DEPS")
  # print(ctx.attr.deps)

  mydeps = get_all_deps(ctx.attr.deps)

  # print("PPX BINARY OPAM DEPS")
  # print(mydeps.opam)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  outfilename = ctx.label.name
  outbinary = ctx.actions.declare_file(outfilename)
  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  args = ctx.actions.args()
  # we will pass ocamlfind as the exec arg, so we start args with ocamlopt
  args.add("ocamlopt")
  args.add_all(ctx.attr.opts)
  args.add("-o", outbinary)

  # for wrapper gen:
  # args.add("-w", "-24")

  ## findlib says:
  ## "If you want to create an executable, do not forget to add the -linkpkg switch."
  # http://projects.camlcity.org/projects/dl/findlib-1.8.1/doc/QUICKSTART
  # args.add("-linkpkg")
  # args.add("-linkall")

  build_deps = []
  includes = []

  args.add_all([dep.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

  for dep in ctx.attr.deps:
    # if OpamPkgInfo in dep:
    #   args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
    #   # build_deps.append(dep[OpamPkgInfo].pkg)
    # else:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".cmx"):
          args.add(g)
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          args.add(g)
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

  return [DefaultInfo(executable=outbinary,
                      files = depset(direct = [outbinary])),
          PpxBinaryProvider(
            payload=outbinary,
            args = depset(direct = ctx.attr.args),
            deps = struct(
              opam = mydeps.opam,
              nopam = mydeps.nopam
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
    srcs = attr.label_list(
      allow_files = OCAML_IMPL_FILETYPES
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
    mode = attr.string(default = "native"),
    message = attr.string()
  ),
  provides = [DefaultInfo, PpxBinaryProvider],
  executable = True,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
