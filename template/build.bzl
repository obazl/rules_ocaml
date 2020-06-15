def _obazl_template_impl(ctx):
    outfile = ctx.actions.declare_file(ctx.label.name + ".bazel")
    ctx.actions.expand_template(
        output = outfile,
        template = ctx.file.template,
        substitutions = {
            "{MODULE}": ctx.attr.module,
            "{PPX}": ctx.attr.ppx,
            "{TOOL}": ctx.attr.tool,
            "{SRC}": ctx.attr.src,
        },
    )
    return [DefaultInfo(files = depset([outfile]))]

obazl_template = rule(
    implementation = _obazl_template_impl,
    attrs = {
        "module": attr.string(default = "MAIN_MODULE"),
        "ppx": attr.string(default = "MY_PPX"),
        "tool": attr.string(default = ":MYPPX"),
        "src": attr.string(default = "MY_SRC"),
        "template": attr.label(
            allow_single_file = True,
            mandatory = True
        )
    },
)

################################################################
def _ocaml_ppx_tpl_impl(ctx):
    outfile = ctx.actions.declare_file(ctx.label.name + ".bazel")
    ctx.actions.expand_template(
        output = outfile,
        template = ctx.file._template,
        substitutions = {
            "{PPX}": ctx.attr.ppx,
            "{TOOL}": ctx.attr.tool,
            "{SRC}": ctx.attr.src,
        },
    )
    return [DefaultInfo(files = depset([outfile]))]

ocaml_ppx_tpl = rule(
    implementation = _ocaml_ppx_tpl_impl,
    attrs = {
        "ppx": attr.string(default = "my_ppx"),
        "tool": attr.string(default = ":mytool"),
        "src": attr.string(default = "my_src"),
        "_template": attr.label(
            allow_single_file = True,
            default = "ppx.bazel.tpl"
        )
    },
)

################################################################
def _ocaml_preproc_tpl_impl(ctx):
    outfile = ctx.actions.declare_file(ctx.label.name + ".bazel")
    ctx.actions.expand_template(
        output = outfile,
        template = ctx.file._template,
        substitutions = {
            "{PPX}": ctx.attr.ppx,
            "{TOOL}": ctx.attr.tool,
            "{SRC}": ctx.attr.src,
        },
    )
    return [DefaultInfo(files = depset([outfile]))]

ocaml_preproc_tpl = rule(
    implementation = _ocaml_preproc_tpl_impl,
    attrs = {
        "ppx": attr.string(default = "my_ppx"),
        "tool": attr.string(default = ":mytool"),
        "src": attr.string(default = "my_src"),
        "_template": attr.label(
            allow_single_file = True,
            default = "preproc.genrule.tpl"
        )
    },
)
