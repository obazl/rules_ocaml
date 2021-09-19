load("//ocaml:providers.bzl",
     "PpxLibraryMarker",
     "PpxModuleMarker")

load(":options.bzl", "options", "options_library")

load(":impl_library.bzl", "impl_library")

###############################
rule_options = options("ocaml")
rule_options.update(options_library("ppx"))

###################
ppx_library = rule(
    implementation = impl_library,
    doc = """Aggregates a collection of PPX modules/libraries/archives. Does not create anything, just passes dependencies through.  Purpose is to make collection available under a single target.
    """,
    attrs = dict(
        rule_options,
        _rule = attr.string( default = "ppx_library" ),
    ),
    # cfg     = ppx_mode_transition,
    provides = [PpxLibraryMarker],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
