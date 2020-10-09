load("//implementation:common.bzl",
     "OCAML_VERSION")
load("//implementation/actions:ppx.bzl",
     "apply_ppx",
     "compile_new_srcs")
load("//implementation/actions:ocaml.bzl",
     "ocaml_compile")
load("//implementation:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("//implementation:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

# /Users/gar/.opam/4.07.1/bin/ocamldep.opt
# -modules
# -impl src-ocaml/baijiu_blake2b.ml
# > _build/default/src-ocaml/.digestif_ocaml.objs/baijiu_blake2b.ml.d

################################################################
def _ocaml_deps_impl(ctx):
  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  args = ctx.actions.args()
  args.add_all(ctx.attr.opts)

  args.add("-sort")

  deps = []

  ordered_srcs = sorted(ctx.files.srcs)

  depfile = ctx.actions.declare_file(ctx.attr.outfile)
  # cmd = ""
  # for src in [x for x in ctx.files.srcs if not x.path.endswith(".mli")]:
  #   # depfile = ctx.actions.declare_file(src.basename + ".depends")
  #   # deps.append(depfile)
  #   cmd = cmd + tc.ocamldep.path + " -modules -native -one-line -impl " + src.path + " >> " + depfile.path + ";\n"

  depfile = ctx.actions.declare_file(ctx.attr.outfile)
  files = [src.path for src in ctx.files.srcs]
  cmd = tc.ocamldep.path + " -modules -all -native " + " ".join(files) + " > " + depfile.path

  ctx.actions.run_shell(
    env = env,
    tools = [tc.ocamldep],
    command = cmd,
    # command = tc.ocamldep.path + " $1 -impl $2 >> " + depfile.path,
    # arguments = [args, src.path, depfile.path],
    inputs = ctx.files.srcs,
    outputs = [depfile],
    progress_message = "ocaml_deps({}): {}".format(
      ctx.label.name, "foo"
    )
  )

  return [DefaultInfo(files = depset(direct = ordered_srcs + [depfile]))]

################################################################
ocaml_deps = rule(
  implementation = _ocaml_deps_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    srcs = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    opts = attr.string_list(),
    outfile = attr.string(
      mandatory = True
    )
  ),
  executable = False,
  toolchains = ["//:toolchain"],
)
