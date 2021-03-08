load("@bazel_skylib//lib:collections.bzl", "collections")

load("//ocaml:providers.bzl",
     "OcamlSDK",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxLibraryProvider",
     "PpxCompilationModeSettingProvider",
     "PpxModuleProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "split_srcs",
     "strip_ml_extension",
)
load(":options.bzl", "options")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_transitions:transitions.bzl", "ppx_mode_transition")

load(":impl_library.bzl", "impl_library")

# print("implementation/ocaml.bzl loading")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

###################
ppx_library = rule(
    implementation = impl_library,
    doc = """Aggregates a collection of PPX modules/libraries/archives. Does not create anything, just passes dependencies through.  Purpose is to make collection available under a single target.
    """,
    attrs = dict(
        options("ocaml"),
        modules = attr.label_list(
            doc = "List of components.",
            providers = [[DefaultInfo], [PpxModuleProvider]]
        ),
        # deps_adjunct = attr.label_list(
        #     providers = [[DefaultInfo], [PpxModuleProvider]]
        # ),
        _mode = attr.label(
            default = "@ppx//mode"
        ),
        _rule = attr.string( default = "ppx_library" ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path"),
        # _allowlist_function_transition = attr.label(
        #     ## required for transition fn of attribute _mode
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        ),
    ),
    # cfg     = ppx_mode_transition,
    provides = [DefaultInfo, PpxLibraryProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
