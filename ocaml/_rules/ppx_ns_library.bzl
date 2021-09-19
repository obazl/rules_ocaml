load("//ocaml:providers.bzl",
     "PpxNsLibraryMarker")

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ns_library")

load(":impl_ns_library.bzl", "impl_ns_library")

load("//ocaml/_transitions:ns_transitions.bzl", "nslib_in_transition")

###############################
rule_options = options("ppx")
rule_options.update(options_ns_opts("ppx"))
rule_options.update(options_ns_library("ppx"))

######################
ppx_ns_library = rule(
    implementation = impl_ns_library,
    doc = """Generate a PPX namespace module.

    """,
    attrs = dict(
        rule_options,
        _rule = attr.string(default = "ppx_ns_library"),
    ),
    cfg     = nslib_in_transition,
    provides = [PpxNsLibraryMarker],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
