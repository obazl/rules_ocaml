load("//ocaml:providers.bzl",
     "PpxLibraryProvider",
     "PpxModuleProvider")

load(":options.bzl", "options", "options_library")

# load("//ocaml/_transitions:transitions.bzl", "ppx_mode_transition")

load(":impl_library.bzl", "impl_library")

# print("implementation/ocaml.bzl loading")

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
        modules = attr.label_list(
            doc = "List of components.",
            providers = [[DefaultInfo], [PpxModuleProvider]]
        ),
        _rule = attr.string( default = "ppx_library" ),
    ),
    # cfg     = ppx_mode_transition,
    provides = [PpxLibraryProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
