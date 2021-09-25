load("//ocaml:providers.bzl",
     "OcamlArchiveMarker",
     "OcamlNsMarker")

load(":options.bzl", "options", "options_ns_archive", "options_ns_opts")

load("//ocaml/_transitions:ns_transitions.bzl", "nsarchive_in_transition")

load(":impl_archive.bzl", "impl_archive")

###############################
rule_options = options("ocaml")
rule_options.update(options_ns_archive("ocaml"))
rule_options.update(options_ns_opts("ocaml"))

########################
ocaml_ns_archive = rule(
    implementation = impl_archive,
    doc = """Generate a 'namespace' module. [User Guide](../ug/ocaml_ns.md).  Provides: [OcamlNsMarker](providers_ocaml.md#ocamlnsmoduleprovider).

**NOTE** 'name' must be a legal OCaml module name string.  Leading underscore is illegal.

See [Namespacing](../ug/namespacing.md) for more information on namespaces.

    """,
    attrs = dict(
        rule_options,
        _rule = attr.string(default = "ocaml_ns_archive")
    ),
    cfg     = nsarchive_in_transition,
    provides = [OcamlNsMarker, OcamlArchiveMarker],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
