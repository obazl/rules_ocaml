load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_providers:ppx.bzl", "PpxExecutableProvider")

load("//ocaml/_utils:deps.bzl", "get_all_deps")
load("//implementation:utils.bzl",
     "OCAML_IMPL_FILETYPES",
     "get_opamroot",
     "get_sdkpath")


##FIXME: handle expected failures

################################################################
########## RULE:  PPX_TRANSFORM  ################
def _gen_test_script(ppx, lib, f):
    """Return shell commands for ppx preprocessing of file 'f'."""

    # We write information to stdout. It will show up in logs, so that the user
    # knows what happened if the test fails.
    return """
{ppx} --cookie 'library-name="{lib}"' \
-o /dev/null 2>&1 \
--impl {file} \
-corrected-suffix .ppx-corrected \
-diff-cmd -;
if [ $? -eq 0 ]; then
    echo PASS: {file};
else
    err=$?
    # echo FAIL: {file};
    echo
fi
""".format(ppx = ppx.short_path, lib = lib, file = f.short_path)
  # --dump-ast;

################
def ppx_transform_impl(ctx):

  debug = False
  # if (ctx.label.name == "snark0.cm_"):
  # # if (ctx.label.name == "versioned_module_bad_missing_to_latest"):
  #     debug = True

  if debug:
      print("PPX_TRANSFORM TARGET: %s" % ctx.label.name)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  for v in ctx.var:
      print("\nVAR: {}: {}".format(v, ctx.var[v]))

  output_file = None
  output_arg = ""
  if "-print-transformations" in ctx.attr.args:
      output_file = ctx.actions.declare_file(
          paths.replace_extension(ctx.file.src.basename, ".transformations")
      )
      # output_arg.append("-o")
      # output_arg.append(output_file)
      output_arg = " 2>&1 > $2"
  elif "-print-passes" in ctx.attr.args:
      output_file = ctx.actions.declare_file(
          paths.replace_extension(ctx.file.src.basename, ".passes")
      )
      # output_arg.append("2>&1")
      # output_arg.append(">")
      # output_arg.append(output_file)
      output_arg = " 2>&1 > $2"
  else:
      output_file = ctx.actions.declare_file(
          paths.replace_extension(ctx.file.src.basename, ".pp.ml")
      )
      # output_arg.append("2>&1")
      # output_arg.append(">")
      # output_arg.append(output_file)
      output_arg = " -o $2"

  mydeps = get_all_deps("ocaml_module", ctx)

  build_deps = []
  dep_graph  = []
  includes   = []

  # dep_graph.append(ctx.file.ppx)
  dep_graph.append(ctx.file.src)

  ################
  cmd = ctx.file.ppx.path
  args = ctx.actions.args()

  # args.add_all([arg for arg in ctx.attr.args]) # , before_each="-package")
  cmd = cmd + " " + " ".join(ctx.attr.args)

  if ctx.attr.output_format == "binary":
      # args.add("-dump-ast")
      cmd = cmd + " -dump-ast"

  # args.add("-o", output_file)
  # args.add_all(output_arg)
  # args.add("-impl", ctx.file.src)
  args.add(ctx.file.src)
  args.add(output_file)

  cmd = cmd + output_arg
  cmd = cmd + " -impl $1"

  # opam_deps = mydeps.opam.to_list()
  # if len(opam_deps) > 0:
  #     args.add("-linkpkg")
  #     for dep in opam_deps:  # mydeps.opam.to_list():
  #         args.add("-package", dep.pkg.to_list()[0].name)

  # we should not have any nopam deps for a ppx xform, but just in
  # case:
  for dep in mydeps.nopam.to_list():
        dep_graph.append(dep)
        build_deps.append(dep)
        includes.append(dep.dirname)

  if debug:
      print("ARGS:")
      print(args)
      print("cmd: %s" % ctx.file.ppx.path)
      print("depgraph: %s" % dep_graph)

  ctx.actions.run_shell(
    env = env,
    # executable = ctx.file.ppx,
    command = cmd,
    arguments = [args],
    inputs = dep_graph,
    outputs = [output_file],
    tools = [ctx.file.ppx],
    mnemonic = "PpxTransform",
    progress_message = "PPX transforming"
  )

  return [DefaultInfo(files = depset(direct = [output_file]))]

################
ppx_transform = rule(
  implementation = ppx_transform_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    ppx = attr.label(
        mandatory = True,
        providers = [[DefaultInfo], [PpxExecutableProvider]],
        executable = True,
        cfg = "host",
        allow_single_file = True
    ),
    args  = attr.string_list(
      doc = "Options to pass to PPX binary.",
    ),
    deps = attr.label_list(
        providers = [
            [OpamPkgInfo],
            # [OcamlArchiveProvider],
            # [OcamlInterfaceProvider],
            # [OcamlModuleProvider],
            # [PpxArchiveProvider],
            # [PpxModuleProvider],
        ]
    ),
    output_format = attr.string(
      doc = "Format of output of PPX transform, binary (default) or text",
      values = ["binary", "text"],
      default = "binary"
    ),
    src = attr.label(
      allow_single_file = [".ml", ".mli"]
    ),
    # deps = attr.label_list( ),
    mode = attr.string(default = "native"),
    message = attr.string()
  ),
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
