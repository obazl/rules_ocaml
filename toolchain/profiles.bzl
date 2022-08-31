def toolchain_profile_selector(
    name, profile,
    toolchain_type = "@rules_ocaml//toolchain/type:profile",
    build_host_constraints=None,
    target_host_constraints=None,
    toolchain_constraints=None,
    visibility = ["//visibility:public"]):

    native.toolchain(
        name                   = name,
        toolchain              = profile,
        toolchain_type         = toolchain_type,
        exec_compatible_with   = build_host_constraints,
        target_compatible_with = target_host_constraints,
        target_settings        = toolchain_constraints,
        visibility             = visibility
    )

#############################
def _ocaml_toolchain_profile_impl(ctx):

    return [platform_common.ToolchainInfo(
        name    = ctx.label.name,
        compile_opts = ctx.attr.compile_opts,
        archive_opts = ctx.attr.archive_opts,
        link_opts    = ctx.attr.link_opts
    )]

#####################
ocaml_toolchain_profile = rule(
    _ocaml_toolchain_profile_impl,
    attrs = {
        "compile_opts": attr.string_list(
            doc     = "Options for compiling modules and signatures",
        ),
        "archive_opts": attr.string_list(
            doc     = "Options for linking archives",
        ),
        "link_opts": attr.string_list(
            doc     = "Options for linking executables",
        )
    },
    doc = "Defines compile/archive/link options for selected toolchain.",
    provides = [platform_common.ToolchainInfo],
)
