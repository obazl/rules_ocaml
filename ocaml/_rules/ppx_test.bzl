load("//ocaml/_providers:ppx.bzl", "PpxExecutableProvider")
load("//implementation:utils.bzl", "OCAML_IMPL_FILETYPES")
# load("ppx_transform.bzl", "ppx_transform_impl")
# load("ocaml_module.bzl", "ocaml_module")

##FIXME: "-diff-cmd -" disables diffing - what if user doesn't want that?

## FIXME: handle -cookie better

################################################################
########## RULE:  PPX_TEST  ################
# ppx doc:  "-null   Produce no output, except for errors"
# using -null instead of "-o /dev/null 2>&1"
def _gen_test_script(ppx, inparam, verbose):
    """Return shell commands for ppx preprocessing of file 'f'."""

    # We write information to stdout. It will show up in logs, so that the user
    # knows what happened if the test fails.
    return """
{verbose}
{ppx} \
-null \
{inparam} \
-diff-cmd -;
exit $?
""".format(ppx = ppx.short_path,
           inparam = inparam,
           verbose=verbose)

################
def _ppx_test_impl(ctx):

  verbose = ""
  if ctx.attr.verbose:
      verbose = "set -x"

  inparam = ""
  if ctx.file.src.extension == "ml":
      inparam = "--impl " + ctx.file.src.short_path
  else:
      inparam = "--intf " + ctx.file.src.short_path

  script = "\n".join(
    ["#!/bin/sh",
     "err=0"] +
    [_gen_test_script(ctx.file.ppx,
                      inparam,
                      verbose)] +
    ["exit $err"],
  )

  # print("TEST SCRIPT:")
  # print(script)

  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = script,
  )

  # To ensure the files needed by the script are available, we put
  # them in the runfiles. The merge is what ensures deps are built and
  # accessible - without it, we get "no such file or directory for the
  # ppx_exe (which is a runfile from the perspective of the test script).
  runfiles = ctx.runfiles(files = [ctx.file.src] + ctx.files.deps
                          ).merge(ctx.attr.ppx[DefaultInfo].default_runfiles)
  return [DefaultInfo(runfiles = runfiles,
                      executable = ctx.outputs.executable)]

################
ppx_test = rule(
  implementation = _ppx_test_impl,
  test = True,
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
    # args  = attr.string_list(
    #   doc = "Options to pass to PPX binary.",
    # ),
    output = attr.string(
      doc = "Format of output of PPX transform, binary (default) or text",
      values = ["binary", "text"],
      default = "binary"
    ),
    src = attr.label(
      allow_single_file = [".ml", ".mli"],
    ),
    deps = attr.label_list( ),
    mode = attr.string(default = "native"),
    verbose = attr.bool(
        doc = "Adds 'set -x' to the script run by this rule, so the effective command (with substitutions) will be written to the log.",
        default = False
    ),
    message = attr.string()
  ),
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)

################################################################
########## RULE:  PPX_FAIL_TEST  ################
def _gen_fail_script(ppx, expected, inparam, verbose):
    """Return shell commands for ppx preprocessing of file 'f' with expected fail."""
    return """
{verbose}
EXPECTED='{expected}'
ACTUAL=$({ppx} \
-null \
{inparam} \
2>&1 > /dev/null);
if [[ $EXPECTED == $ACTUAL ]]
then
    exit 0
else
    echo "EXPECTED:\n$EXPECTED"
    echo "ACTUAL:\n$ACTUAL"
    exit 1
fi
""".format(ppx = ppx.short_path, expected = expected, inparam = inparam, verbose=verbose)

#################################################
################  PPX_FAIL_TEST  ################
def _ppx_fail_test_impl(ctx):

  inparam = ""
  if ctx.file.src.extension == "ml":
      inparam = "--impl " + ctx.file.src.short_path
  else:
      inparam = "--intf " + ctx.file.src.short_path

  verbose = ""
  if ctx.attr.verbose:
      verbose = "set -x"

  script = "\n".join(
    [_gen_fail_script(ctx.file.ppx,
                      ctx.attr.expected,
                      inparam,
                      verbose)]
  )

  # print("SCRIPT:")
  # print(script)

  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = script,
  )

  runfiles = ctx.runfiles(files = [ctx.file.src] + ctx.files.deps
                          ).merge(ctx.attr.ppx[DefaultInfo].default_runfiles)
  return [DefaultInfo(runfiles = runfiles,
                      executable = ctx.outputs.executable)]

#################################################
ppx_fail_test = rule(
  implementation = _ppx_fail_test_impl,
  test = True,
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
    expected = attr.string(
    ),
    # args  = attr.string_list(
    #   doc = "Options to pass to PPX binary.",
    # ),
    output = attr.string(
      doc = "Format of output of PPX transform, binary (default) or text",
      values = ["binary", "text"],
      default = "binary"
    ),
    src = attr.label(
      allow_single_file = [".ml", ".mli"],
    ),
    deps = attr.label_list( ),
    mode = attr.string(default = "native"),
    verbose = attr.bool(
        doc = "Adds 'set -x' to the script run by this rule, so the effective command (with substitutions) will be written to the log.",
        default = False
    ),
    message = attr.string()
  ),
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)


################################################################
########## RULE:  PPX_DIFF_TEST  ################
#### run diff against ppx result and a test data file
def _gen_diff_script(ppx, cookies, expected, inparam, outfile, verbose):
    """Return shell commands for ppx preprocessing of file 'src'."""
    return """
{verbose}
{ppx} \
{cookies} \
$@ \
-o $TEST_UNDECLARED_OUTPUTS_DIR/{outfile} \
{inparam}
if [[ $? == 0 ]]
then
    diff {expected} $TEST_UNDECLARED_OUTPUTS_DIR/{outfile}
    exit $?
else
    exit 1
fi
""".format(ppx = ppx.short_path,
           cookies = cookies,
           # args = args,
           expected = expected.short_path,
           inparam = inparam,
           outfile = outfile,
           verbose = verbose)
  # --dump-ast;

#################################################
################  PPX_DIFF_TEST  ################
def _ppx_diff_test_impl(ctx):

  # cookies are legacy, do we need this?
  cookies = ""
  for key in ctx.attr.cookies:
      # print("key: %s" % key)
      cookies = cookies + "-cookie '" + key + "=\"" + ctx.attr.cookies[key] + "\"'"

  inparam = ""
  if ctx.file.src.extension == "ml":
      inparam = "--impl " + ctx.file.src.short_path
      outfile = ctx.file.src.basename + ".pp.ml"
  else:
      inparam = "--intf " + ctx.file.src.short_path
      outfile = ctx.file.src.basename + ".pp.mli"

  # print("INPARAM: %s" % inparam)
  # print("OUTFILE: %s" % outfile)

  verbose = ""
  if ctx.attr.verbose:
      # if debug:
      #     print("VERBOSE")
      verbose = "set -x"
      # print("COOKIES: %s" % cookies)

  script = "\n".join(
    [_gen_diff_script(ctx.file.ppx,
                      cookies,
                      ctx.file.expected,
                      inparam,
                      outfile,
                      verbose)]
  )

  # print("Script:")
  # print(script)

  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = script,
  )

  runfiles = ctx.runfiles(files = [ctx.file.src, ctx.file.expected] + ctx.files.deps
                          ).merge(ctx.attr.ppx[DefaultInfo].default_runfiles)
  return [DefaultInfo(runfiles = runfiles,
                      executable = ctx.outputs.executable)]

#################################################
ppx_diff_test = rule(
  implementation = _ppx_diff_test_impl,
  test = True,
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
    verbose = attr.bool(
        doc = "Adds 'set -x' to the script run by this rule, so the effective command (with substitutions) will be written to the log.",
        default = False
    ),
    # to support legacy stuff. cookies not needed with "modern" ppxlib + OMP
    cookies = attr.string_dict(
        doc = """
Some PPX libs (e.g. foo) take '-cookie' arguments, which must have the form 'name="value"'. Since it is easy to get the quoting wrong due to shell substitutions, this attribute makes it easy. Keys are cookie names, values are cookie vals.
 """
    ),
    expected = attr.label(
        allow_single_file = True,
    ),
    # args  = attr.string_list(
    #   doc = "Options to pass to PPX binary.",
    # ),
    src = attr.label(
      allow_single_file = [".ml", ".mli"]
    ),
    output = attr.string(
      doc = "Format of output of PPX transform, binary (default) or text",
      values = ["binary", "text"],
      default = "binary"
    ),
    deps = attr.label_list( ),
    mode = attr.string(default = "native"),
    message = attr.string()
  ),
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)


################################################################
## testing the rules themselves
## https://docs.bazel.build/versions/master/skylark/testing.html#failure-testing
# def _ppx_fail_test_impl(ctx):
#     env = analysistest.begin(ctx)
#     asserts.expect_failure(env, "This rule should never work")
#     return analysistest.end(env)

# ppx_fail_test = analysistest.make(
#     _ppx_fail_test_impl,
#     expect_failure = True,
# )


# def _xfail_test(do_binary, name,
#                 size = None, timeout = None, shard_count = None,
#                 visibility = None, **kwargs):
#   if 'flaky' in kwargs:
#     fail('not supported for xfail_tests', 'flaky')
#   if 'args' in kwargs:
#     fail('not yet implemented for xfail_tests', 'args')
#   if 'shard_count' in kwargs:
#     fail('not yet implemented for xfail_tests', 'shard_count')

#   do_binary(
#     name = name + '__binary',
#     visibility = ['//visibility:implementation'],
#     testonly = True,
#     **kwargs
#   )

#   native.sh_test(
#     name = name,
#     visibility = visibility,
#     size = size,
#     timeout = timeout,
#     shard_count = shard_count,
#     srcs = [
#       '//tools/test:run_xfail_test',
#     ],
#     data = [
#       ':%s__binary' % name,
#     ],
#     args = [
#       '$(location :%s__binary)' % name,
#     ],
#   )
