load("@bazel_skylib//lib:paths.bzl", "paths")

load("@obazl//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxBinaryProvider",
     "PpxModuleProvider")
load("@obazl//ocaml/private:actions/batch.bzl", "copy_srcs_to_tmp")
load("@obazl//ocaml/private:actions/ns_module.bzl", "ns_module_action")
load("@obazl//ocaml/private:actions/module.bzl", "rename_module", "transform_module")
# load("@obazl//ocaml/private:actions/ppx.bzl",
     # "apply_ppx",
     # "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     # "ocaml_ppx_library_gendeps",
     # "ocaml_ppx_library_cmo",
     # "ocaml_ppx_library_compile",
     # "ocaml_ppx_library_link")
load("@obazl//ocaml/private:utils.bzl",
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

  mydeps = get_all_deps(ctx.attr.deps)

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  srcs = None
  impl_src_file = get_target_file(ctx.attr.impl)
  if ctx.attr.ppx:
    srcs = transform_module("ppx_module", ctx, struct(impl = impl_src_file, intf = ctx.attr.intf))
  elif ctx.attr.ns:
    srcs = rename_module(ctx, struct(impl = impl_src_file, intf = ctx.attr.intf), ctx.attr.ns)
  else:
    srcs = struct(impl = impl_src_file, intf = ctx.attr.intf if ctx.attr.intf else None)

  # srcs now contains declared output files, and we no longer need ns or ppx
  # srcs :: struct( impl :: declared File, maybe intf :: File )
  print("SRCS: %s" % srcs)

  obj = {}

  if srcs.intf:
    obj["cmi"]       = ctx.actions.declare_file(paths.replace_extension(srcs.intf.short_path, ".cmi"))
  else:
    obj["cmi"]       = ctx.actions.declare_file(paths.replace_extension(srcs.impl.short_path, ".cmi"))

  obj["cm"]          = ctx.actions.declare_file(paths.replace_extension(srcs.impl.short_path, ".cmx"))
  obj["o"]           = ctx.actions.declare_file(paths.replace_extension(srcs.impl.short_path, ".o"))

  # if srcs.intf:
  #   out_cmi = compile_interface(ctx, srcs.intf)

  # out_module = compile_module(ctx, srcs)

  # # lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  args = ctx.actions.args()
  args.add(tc.compiler.basename)
  args.add("-w", ctx.attr.warnings)
  options = tc.opts + ctx.attr.opts
  args.add_all(options)

  if ctx.attr.ns:
    args.add("-no-alias-deps")
    args.add("-opaque")

  args.add("-c")
  args.add("-o", obj["cm"])

  build_deps = []
  includes = []

  ## transitive opam deps
  args.add_all([dep.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

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

  if linkpkg_flag:
    args.add("-linkpkg")

  args.add_all(includes, before_each="-I", uniquify = True)

  # non-ocamlfind-enabled deps:
  args.add_all(build_deps)

  args.add(srcs.impl)

  inputs = build_deps + [srcs.impl]
  # print("INPUTS:")
  # print(inputs)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs,
    outputs = obj.values(),
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt] + ctx.files.data,
    mnemonic = "OcamlPPXBinary",
    progress_message = "ppx_module({}), {}".format(
      ctx.label.name, ctx.attr.msg
      )
  )

  # return [DefaultInfo(files = depset(direct = [obj_cm, obj_cmi])),
  #         PpxModuleProvider(
  #           payload = struct(
  #             cmi = obj_cmi,
  #             cm = obj_cm,
  #             # o   = obj_o
  #           ),
  #           deps = struct(
  #             opam = mydeps.opam,
  #             nopam = mydeps.nopam
  #           )
  #         )]

  # print("srcs.impl: %s" % srcs.impl)
  # testing:
  return [
    DefaultInfo(files = depset(direct = obj.values())),
    PpxModuleProvider(
      payload = struct(
        cmi = obj["cmi"],
        cm  = obj["cm"],
        o   = obj["o"]
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
    impl = attr.label(
      mandatory = True,  # use ocaml_interface for isolated .mli files
      allow_single_file = OCAML_IMPL_FILETYPES
    ),
    intf = attr.label(
      allow_single_file = OCAML_INTF_FILETYPES
    ),
    ppx  = attr.label(
      doc = "PPX binary (executable).",
      providers = [PpxBinaryProvider]
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
  toolchains = ["@obazl//ocaml:toolchain"],
)
