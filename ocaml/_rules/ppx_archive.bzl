load("//ocaml:providers.bzl",
     "PpxArchiveProvider",
     "PpxModuleProvider")

load(":options.bzl", "options")

load(":impl_archive.bzl", "impl_archive")

###################
ppx_archive = rule(
    implementation = impl_archive,
    doc = """Generates an OCaml archive file suitable for use as a PPX dependency.   Provides: [PpxArchiveProvider](providers_ppx.md#ppxarchiveprovider).
    """,
    attrs = dict(
        options("ocaml"),
        archive_name = attr.string(
            doc = "Name of generated archive file, without extension. Overrides `name` attribute."
        ),
        ## CONFIGURABLE DEFAULTS
        _linkall     = attr.label(default = "@ppx//archive/linkall"),
        _thread     = attr.label(default = "@ppx//archive/thread"),
        _warnings  = attr.label(default = "@ppx//archive:warnings"),
        #### end options ####

        modules = attr.label_list(
            doc = "List of OCaml build dependencies to include in archive.",
            providers = [[PpxModuleProvider]]
        ),
        cc_deps = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            providers = [[CcInfo]]
        ),
        cc_linkopts = attr.string_list(
            doc = "List of C/C++ link options. E.g. `[\"-lstd++\"]`.",
        ),
        cc_linkall = attr.label_list(
            doc     = "True: use `-whole-archive` (GCC toolchain) or `-force_load` (Clang toolchain). Deps in this attribute must also be listed in cc_deps.",
            providers = [CcInfo],
        ),
        _cc_linkmode = attr.label(
            doc     = "Override platform-dependent link mode (static or dynamic). Configurable default is platform-dependent: static on Linux, dynamic on MacOS.",
            # default is os-dependent, but settable to static or dynamic
        ),
        _mode = attr.label(
            default = "@ppx//mode",
            # cfg     = ppx_mode_transition
        ),
        _projroot = attr.label(
            default = "@ocaml//:projroot"
        ),
        _rule = attr.string( default = "ppx_archive" ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        )
        # _allowlist_function_transition = attr.label(
        # default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    # cfg     = ppx_mode_transition,
    provides = [PpxArchiveProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
