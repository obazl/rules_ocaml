load("//ocaml:providers.bzl",
     "OcamlNsResolverProvider",
     "PpxNsArchiveProvider")

load(":options.bzl", "options", "options_ns_archive", "options_ns_opts")

load(":impl_ns_archive.bzl", "impl_ns_archive")

load("//ocaml/_transitions:ns_transitions.bzl", "nsarchive_in_transition")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

###############################
rule_options = options("ocaml")
rule_options.update(options_ns_archive("ppx"))
rule_options.update(options_ns_opts("ocaml"))

######################
ppx_ns_archive = rule(
    implementation = impl_ns_archive,
    doc = """Generate a PPX namespace module.

    """,
    attrs = dict(
        rule_options,
        _rule = attr.string(default = "ppx_ns_archive")
    ),
    cfg     = nsarchive_in_transition,
    provides = [PpxNsArchiveProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
