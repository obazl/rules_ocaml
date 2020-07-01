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

########## RULE:  PPX_TEST  ################
def _ppx_test_impl(ctx):

  script = "\n".join(
    ["err=0"] +
    [_preprocess_file(ctx.file.ppx,
                      "unexpired",
                      f) for f in ctx.files.srcs] +
    ["exit $err"],
  )

  ## force build of deps?
  ctx.actions.do_nothing(mnemonic="require ppx",
                         inputs=ctx.attr.ppx.files)
                         # inputs=ctx.attr.ppx.files + depset(direct=[ctx.attr.ppx]))

  # Write the file, it is executed by 'bazel test'.
  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = script,
  )

  # To ensure the files needed by the script are available, we put them in
  # the runfiles.
  runfiles = ctx.runfiles(files = ctx.files.srcs + ctx.files.deps)
  return [DefaultInfo(runfiles = runfiles, executable = ctx.outputs.executable)]

#################################################
######### DECL:  PPX_TEST  ################
## A ppx_test rule builds and runs a ppx executable on an input file.
## Just like ppx_binary, but with an additional parameter to specify
## the file to preprocess.

ppx_test = rule(
  implementation = _ppx_test_impl,
  test = True,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    ppx = attr.label(
        mandatory = True,
        executable = True,
        cfg = "host",
        allow_single_file = True
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
