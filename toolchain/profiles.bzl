def toolchain_profile_selector(name, profile,
                               target_compatible_with=None,
                               target_settings=None):
    native.toolchain(
        name = name,
        toolchain = profile,
        toolchain_type         = "@rules_ocaml//toolchain/type:profile",
        target_compatible_with = target_compatible_with,
        target_settings        = target_settings,
        visibility             = ["//visibility:public"]
    )

#############################
def _ocaml_profile_impl(ctx):

    return [platform_common.ToolchainInfo(
        name    = ctx.label.name,
        compile_opts = ctx.attr.compile_opts,
        archive_opts = ctx.attr.archive_opts,
        link_opts    = ctx.attr.link_opts
    )]

#####################
ocaml_profile = rule(
    _ocaml_profile_impl,
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
