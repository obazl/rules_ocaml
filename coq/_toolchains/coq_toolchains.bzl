# load("//ocaml:providers.bzl",
#      "CompilationModeSettingProvider",
#      "OcamlSDK")

## obtaining CC toolchain:  https://github.com/bazelbuild/bazel/issues/7260

###################################################################
def coq_register_toolchains(installation = None, noocaml = None):

    # native.register_toolchains("@coq_sdk//toolchains:coq_linux")
    # native.register_toolchains("@coq_sdk//toolchains:coq_macos")

    native.register_toolchains("@obazl_rules_ocaml//coq:coq_linux")
    native.register_toolchains("@obazl_rules_ocaml//coq:coq_macos")

################################################################
_coq_tools_attrs = {
    "path": attr.string(),
    "sdk_home": attr.string(),

    ## FIXME: these should be provided by the toolchain definition?
    "coqc": attr.label(
        # default = Label("@coq_sdk//tools:coqc"),
        executable = True,
        cfg = "exec",
        allow_single_file = True,
    ),
    "_copts": attr.string_list(
        default = [
        ]
    ),
}

def _coq_toolchain_impl(ctx):

    return [platform_common.ToolchainInfo(
        # Public fields
        name = ctx.label.name,
        sdk_home   = ctx.attr.sdk_home,
        coqc       = ctx.attr.coqc.files.to_list()[0],
        copts       = ctx.attr._copts,
    )]

coq_toolchain = rule(
    _coq_toolchain_impl,
    attrs = _coq_tools_attrs,
    doc = "Defines a Coq toolchain based on an SDK",
    provides = [platform_common.ToolchainInfo],
)
