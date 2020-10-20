load("//ocaml/_providers:ppx.bzl", "PpxExecutableProvider")
load("//implementation:utils.bzl", "OCAML_IMPL_FILETYPES")
# load("ppx_transform.bzl", "ppx_transform_impl")
# load("ocaml_module.bzl", "ocaml_module")

##FIXME: "-diff-cmd -" disables diffing - what if user doesn't want that?

## FIXME: handle -cookie better

################################################################
########## RULE:  PPX_X_TEST  ################
# ppx doc:  "-null   Produce no output, except for errors"
# using -null instead of "-o /dev/null 2>&1"
def _gen_test_script(ppx, inparam, verbose):
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
def _ppx_x_test_impl(ctx):

  verbose = ""
  if ctx.attr.verbose:
      verbose = "set -x"

  inparam = ""
  if ctx.file.src.extension == "ml":
      inparam = "--impl " + ctx.file.src.short_path
  else:
      inparam = "--intf " + ctx.file.src.short_path

  script = "\n".join(
    ["#!/bin/sh"] +
    [_gen_test_script(ctx.file.ppx,
                      inparam,
                      verbose)]
  )

  print("TEST SCRIPT:")
  print(script)

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
ppx_x_test = rule(
  implementation = _ppx_x_test_impl,
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
# def _ppx_fail_test_impl(ctx):

#   inparam = ""
#   if ctx.file.src.extension == "ml":
#       inparam = "--impl " + ctx.file.src.short_path
#   else:
#       inparam = "--intf " + ctx.file.src.short_path

#   verbose = ""
#   if ctx.attr.verbose:
#       verbose = "set -x"

#   script = "\n".join(
#     [_gen_fail_script(ctx.file.ppx,
#                       ctx.attr.expected,
#                       inparam,
#                       verbose)]
#   )

#   # print("SCRIPT:")
#   # print(script)

#   ctx.actions.write(
#       output = ctx.outputs.executable,
#       is_executable = True,
#       content = script,
#   )

#   runfiles = ctx.runfiles(files = [ctx.file.src] + ctx.files.deps
#                           ).merge(ctx.attr.ppx[DefaultInfo].default_runfiles)
#   return [DefaultInfo(runfiles = runfiles,
#                       executable = ctx.outputs.executable)]

# #################################################
# ppx_fail_test = rule(
#   implementation = _ppx_fail_test_impl,
#   test = True,
#   attrs = dict(
#     _sdkpath = attr.label(
#       default = Label("@ocaml//:path")
#     ),
#     ppx = attr.label(
#         mandatory = True,
#         providers = [[DefaultInfo], [PpxExecutableProvider]],
#         executable = True,
#         cfg = "host",
#         allow_single_file = True
#     ),
#     expected = attr.string(
#     ),
#     # args  = attr.string_list(
#     #   doc = "Options to pass to PPX binary.",
#     # ),
#     output = attr.string(
#       doc = "Format of output of PPX transform, binary (default) or text",
#       values = ["binary", "text"],
#       default = "binary"
#     ),
#     src = attr.label(
#       allow_single_file = [".ml", ".mli"],
#     ),
#     deps = attr.label_list( ),
#     mode = attr.string(default = "native"),
#     verbose = attr.bool(
#         doc = "Adds 'set -x' to the script run by this rule, so the effective command (with substitutions) will be written to the log.",
#         default = False
#     ),
#     message = attr.string()
#   ),
#   toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
# )

################################################################
########## RULE:  PPX_TEST  ################
## https://stackoverflow.com/questions/11027679/capture-stdout-and-stderr-into-different-variables
################################################################
def _gen_expect_stderr_script(ppx, cookies, expected, inparam, outfile, verbose):
    """Return shell commands for ppx preprocessing of file 'src'."""
    return """{ppx} \
-null \
{cookies} \
\"$@\" \
{inparam}""".format(ppx = ppx.short_path,
                    cookies = cookies,
                    expected = expected,
                    inparam = inparam,
                    outfile = outfile,
                    verbose = verbose)

################
def _gen_capture_string_script(s, outfile, expected):
    ## NOTE the pattern of single/double quotes around expected and actual!
    return """
#!/bin/bash
{{
    IFS=$'\\n' read -r -d '' CAPTURED_STDERR;
    IFS=$'\\n' read -r -d '' CAPTURED_STDOUT;
}} < <((printf '\\0%s\\0' "$({script})" 1>&2) 2>&1)
if [[ '{expected}' == $CAPTURED_STDERR ]]
then
    echo SUCCESS
    exit 0
else
    echo 'EXPECTED:\n{expected}'
    echo "ACTUAL:\n${{CAPTURED_STDERR}}"
    exit 1
fi
""".format(script = s, outfile = outfile, expected = expected)

################
def _gen_capture_file_script(s, outfile, expected):
    return """
#!/bin/bash

DIFFCMD="diff -c {expected} $TEST_UNDECLARED_OUTPUTS_DIR/{outfile}"
{script}
if [[ $? == 0 ]]
then
    {{
        IFS=$'\\n' read -r -d '' CAPTURED_STDERR;
        IFS=$'\\n' read -r -d '' CAPTURED_STDOUT;
    }} < <((printf '\\0%s\\0' "$($DIFFCMD)" 1>&2) 2>&1)
    if [[ ${{CAPTURED_STDOUT}} == "" ]]
    then
        exit 0
    else
        echo "$DIFFCMD"
        echo "STDOUT:\n${{CAPTURED_STDOUT}}"
        echo "STDERR:\n${{CAPTURED_STDERR}}"
        exit 1
    fi
else
    exit 1
fi

""".format(script = s, outfile = outfile, expected = expected)

################################################################
def _gen_expect_file_script(ppx, cookies, expected, inparam, outfile, verbose):
    """Return shell commands for ppx preprocessing of file 'src'."""
    return """{ppx} \
{cookies} \
$@ \
-o $TEST_UNDECLARED_OUTPUTS_DIR/{outfile} \
{inparam}
""".format(ppx = ppx.short_path,
           cookies = cookies,
           # args = args,
           expected = expected,
           inparam = inparam,
           outfile = outfile,
           verbose = verbose)

################################################################
def _gen_cmd_script(ppx, cookies, expected_out, expected_err, inparam, outfile, errfile, verbose):
    """Return shell commands for ppx preprocessing of file 'src'."""
    return """
{ppx} \
{cookies} \
$@ \
-o $TEST_UNDECLARED_OUTPUTS_DIR/{stdout_file} \
{inparam} \
2> $TEST_UNDECLARED_OUTPUTS_DIR/{stderr_file}
if  [[ $? == 0 ]]
then
    echo "Comparing actual to expected output"
    diff -c $TEST_UNDECLARED_OUTPUTS_DIR/{stdout_file} {expected_out}
    if [[ $? == 0 ]]
    then
        echo "Comparing actual to expected stderr"
        diff -c $TEST_UNDECLARED_OUTPUTS_DIR/{stderr_file} {expected_err}
        if [[ $? == 0 ]]
        then
            echo "OK"
            exit 0
        else
            exit 1
        fi
    else
        exit 1
    fi
else
    echo "Comparing actual to expected stderr"
    diff -c $TEST_UNDECLARED_OUTPUTS_DIR/{stderr_file} {expected_err}
    if [[ $? == 0 ]]
    then
        echo "OK"
        exit 0
    else
        exit 1
    fi
fi
""".format(ppx = ppx.short_path,
           cookies = cookies,
           expected_out = expected_out,
           expected_err = expected_err,
           inparam = inparam,
           stdout_file = outfile,
           stderr_file = errfile,
           verbose = verbose)

#################################################
################  PPX_TEST  ################
def _ppx_test_impl(ctx):

  print("EXPECT ATTR: %s" % ctx.attr.expect)
  if ctx.attr.expect == {}:
      fail("missing", attr="expect")
  stdout_expect = None;
  stderr_expect = None;
  for item in ctx.attr.expect.items():
      if item[1] in ["stdout", "1"]:
          stdout_expect = item[0].files.to_list()[0]
          print("STDOUT_EXPECT: %s" % stdout_expect)
      elif item[1] in ["stderr", "2"]:
          stderr_expect = item[0].files.to_list()[0]
          print("STDERR_EXPECT: %s" % stderr_expect)
      # else:
      #     fail("Allowed expect item values: \"stdout\", \"1\", \"stderr\", \"2\"]. Got: '%s'" % item[1])

  # cookies are legacy, do we need this?
  cookies = ""
  for key in ctx.attr.cookies:
      # print("key: %s" % key)
      cookies = cookies + "-cookie '" + key + "=\"" + ctx.attr.cookies[key] + "\"'"

  inparam = ""
  if ctx.file.src.extension == "ml":
      inparam = "--impl " + ctx.file.src.path
      stdout_file = ctx.file.src.basename + ".pp.ml"
      stderr_file = ctx.file.src.basename + ".stderr"
  else:
      inparam = "--intf " + ctx.file.src.short_path
      stdout_file = ctx.file.src.basename + ".pp.mli"
      stderr_file = ctx.file.src.basename + ".stderr"

  # print("INPARAM: %s" % inparam)
  # print("OUTFILE: %s" % outfile)

  verbose = ""
  if ctx.attr.verbose:
      # if debug:
      #     print("VERBOSE")
      verbose = "set -x"
      # print("COOKIES: %s" % cookies)

  script = ""
  # if ctx.attr.expect != None:
  # if stdout_expect != None:
  if ctx.attr.expect != None:
      print("EXPECT: %s" % stdout_expect) # ctx.attr.expect)
      run_script = "\n".join(
          ## def _gen_cmd_script(ppx, cookies, expected, inparam, outfile, errfile, verbose):
          [_gen_cmd_script(ctx.executable.ppx,
                           cookies,
                           stdout_expect.short_path if stdout_expect else "",
                           stderr_expect.short_path if stderr_expect else "/dev/null",
                           inparam,
                           stdout_file,
                           stderr_file,
                           verbose)])
      print("Embedded file Script:")
      print(run_script)
  # elif ctx.attr.expect_stderr != "":
  # # elif stderr_expect != None:
  #     ## _gen_expect_stderr_script(ppx, cookies, expected, inparam, outfile, verbose):
  #     script = _gen_expect_stderr_script(ctx.file.ppx,
  #                                        cookies,
  #                                        # stderr_expect.short_path,
  #                                        ctx.attr.expect_stderr,
  #                                        inparam,
  #                                        stdout_file,
  #                                        verbose)
  #     print("Embedded string Script:")
  #     print(script)
  #     run_script = _gen_capture_string_script(script, stdout_file, ctx.attr.expect_stderr)
  #     print("Run Script:")
  #     print(run_script)
  #     # run_script = "\n".join(
  #     #     [_gen_fail_script(ctx.file.ppx,
  #     #                       ctx.attr.expect_stderr,
  #     #                       inparam,
  #     #                       verbose)])
  #     # print("Run Script:")
  #     # print(run_script)
  else:
      fail("Either expect (file) or expect_stderr (string) required.")

  ctx.actions.write(
      output = ctx.outputs.executable,
      is_executable = True,
      content = run_script,
  )

  rfiles = [ctx.file.src] + ctx.files.deps
  # if ctx.file.expect != None:
  #     rfiles.append(ctx.file.expect)
  if stdout_expect != None:
      rfiles.append(stdout_expect)
  if stderr_expect != None:
      rfiles.append(stderr_expect)

  for datum in ctx.attr.data:
      if datum.label.name.startswith(ctx.label.name):
          fail("Disallowed: target name '{t}' is a prefix of a data file '{d}'.".format(
              t = ctx.label.name,
              d = datum.label.name))
  for datum in ctx.files.data:
      rfiles.append(datum)
  runfiles = ctx.runfiles(
      collect_data = True,
      files = rfiles
  ).merge(ctx.attr.ppx[DefaultInfo].default_runfiles)

  return [DefaultInfo( runfiles = runfiles,
                      ##runfiles = ctx.runfiles(collect_data = True),
                      executable = ctx.outputs.executable)]

#################################################
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
    # expect = attr.label(
    #     allow_single_file = True,
    # ),
    expect = attr.label_keyed_string_dict(
        allow_files = True
    ),
    # expect_stderr = attr.string(
    # ),
    data = attr.label_list(
        allow_files = True
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
