load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_providers:ppx.bzl", "PpxExecutableProvider")
load("//ocaml/_utils:deps.bzl", "get_all_deps")
load(
    "//implementation:utils.bzl",
    "OCAML_IMPL_FILETYPES",
    "get_opamroot",
    "get_sdkpath",
)

def _gen_script(ppx, lib, f):
    """Return shell commands for template stamping."""
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

####################################################
########## RULE:  XRULE_STAMP_TEMPLATE  ################

def xrule_stamp_template_impl(ctx):
    """ Generate a file from a template file and workspace status data.

See https://bazelbuild.github.io/rules_nodejs/stamping.html and https://docs.bazel.build/versions/master/user-manual.html#workspace_status.
"""
    debug = False
    # if (ctx.label.name == "snark0.cm_"):
    #     debug = True

    if debug:
        print("XRULE_STAMP_TEMPLATE target: %s" % ctx.label.name)

    print("OUTPUT: %s" % ctx.attr.output)
    outfile = ctx.actions.declare_file(ctx.attr.output.name)
    print("OUTFILE: %s" % outfile)

    # args = ["--stamp-info-file=%s" % f.path for f in (ctx.info_file, ctx.version_file)]
    print("INFO_FILE: %s" % ctx.info_file)
    print("VERSION_FILE: %s" % ctx.version_file)

    subslines = []
    i = 1
    for item in ctx.attr.substitutions.items():
        subslines.append(
            "    LINE=\"${{LINE//{key}/${{{val}}}}}\"".format(
                key = item[0].replace("{", "\\{").replace("}", "\\}"),
                val = item[1],
            ),
        )
        i = i + 1

    cmd = "\n".join([
        "#!/bin/sh",
        # ] + lines + [
        "exec <{}".format(ctx.info_file.path),
        "while read -r K V LINE",  # -r "backslash does not act as an escape char"
        "do",
        "    eval ${K}=$V",
        "done",
        "exec 3>{}".format(outfile.path),
        "exec <{}".format(ctx.file.template.path),
        "while read -r LINE",
        "do",
    ] + subslines + [
        "    echo ${LINE} 1>&3",
        "done",
    ])

    ctx.actions.run_shell(
        command = cmd,
        outputs = [outfile],
        mnemonic = "StampTemplate",
        progress_message = "xrule_stamp_template: {}".format(ctx.file.template.basename),
    )

########################
xrule_stamp_template = rule(
    implementation = xrule_stamp_template_impl,
    attrs = dict(
        output = attr.output(),
        template = attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        substitutions = attr.string_dict(
            doc = "Keys are fields in template file. Values are keys in workspace status file (stable-status.txt), which will be looked up to find replacement strings. See https://bazelbuild.github.io/rules_nodejs/stamping.html and https://docs.bazel.build/versions/master/user-manual.html#workspace_status."
        ),
    ),
)
