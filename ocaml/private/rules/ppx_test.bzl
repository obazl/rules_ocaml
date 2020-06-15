load("@obazl//ocaml/private:utils.bzl", "OCAML_IMPL_FILETYPES")

##FIXME: handle expected failures

##################################################
def _preprocess_file(ppx, lib, f):
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

########## RULE:  OCAML_PPX_TEST  ################
def _ocaml_ppx_test_impl(ctx):

  script = "\n".join(
    ["err=0"] +
    [_preprocess_file(ctx.attr.ppx.files.to_list()[0],
                      "unexpired",
                      f) for f in ctx.files.srcs] +
    ["exit $err"],
  )

  ctx.actions.do_nothing(mnemonic="require ppx", inputs=ctx.attr.ppx.files)

  # Write the file, it is executed by 'bazel test'.
  ctx.actions.write(
    output = ctx.outputs.executable,
    content = script,
  )

  # To ensure the files needed by the script are available, we put them in
  # the runfiles.
  runfiles = ctx.runfiles(files = ctx.files.srcs + ctx.files.deps)
  return [DefaultInfo(runfiles = runfiles)]

  # tc = ctx.toolchains["@obazl//ocaml:toolchain"]
  # env = {"OPAMROOT": get_opamroot(),
  #        "PATH": get_sdkpath(ctx)}

  # ppx = ctx.attr.ppx.files.to_list()[0]
  # outexe = ctx.actions.declare_file(ppx.path)
  # # outfiles = []
  # # for src in ctx.file.srcs:
  # #   outfiles.append(ctx.actions.declare_file(src + "pp.ml")
  # outfile = ctx.actions.declare_file(ctx.files.srcs[0].basename + "pp.ml")

  # args = ctx.actions.args()
  # args.add("--cookie", "library-name=expired")
  # args.add("-o", outfile)
  # args.add("--impl", outfile)
  # args.add("-corrected-suffix", ".ppx-corrected")
  # args.add("-diff-cmd", "-")
  # # args.add("--dump-ast")

  # # equivalent of preproc genrules
  # ctx.actions.run(
  #   env = env,
  #   executable = ppx,
  #   arguments = [args],
  #   inputs = ctx.files.srcs,
  #   outputs = [outfile],
  #   tools = [ppx],
  #   mnemonic = "OcamlPPXTest",
  #   progress_message = "ocaml_ppx_test({}), {}".format(
  #     ctx.label.name, ctx.attr.message
  #     )
  # )

  # runfiles = ctx.runfiles(files = ctx.files.srcs)

  # return [DefaultInfo(runfiles = runfiles)]

#################################################
######### DECL:  OCAML_PPX_TEST  ################
## A ppx_test rule builds and runs a ppx executable on an input file.
## Just like ppx_binary, but with an additional parameter to specify
## the file to preprocess.

ocaml_ppx_test = rule(
  implementation = _ocaml_ppx_test_impl,
  test = True,
  attrs = dict(
    ppx = attr.label(
      mandatory = True,
      allow_single_file = True
    ),
    _sdkpath = attr.label(
      default = Label("@ocaml_sdk//:path")
    ),
    srcs = attr.label_list(
      allow_files = OCAML_IMPL_FILETYPES
    ),
    deps = attr.label_list( ),
    mode = attr.string(default = "native"),
    message = attr.string()
  ),
  toolchains = ["@obazl//ocaml:toolchain"],
)
