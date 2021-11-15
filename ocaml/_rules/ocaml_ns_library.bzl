load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker")

load("//ocaml/_transitions:transitions.bzl",
     "nslib_in_transition")

load(":impl_library.bzl", "impl_library")

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ns_library")

################################
rule_options = options("ocaml")
rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ns_library("ocaml"))
# rule_options.update(options_ppx)

################
ocaml_ns_library = rule(
    implementation = impl_library,
    doc = """Generate a 'namespace' module. [User Guide](../ug/ocaml_ns.md).  Provides: [OcamlNsMarker](providers_ocaml.md#ocamlnsmoduleprovider).

**NOTE** 'name' must be a legal OCaml module name string.  Leading underscore is illegal.

See [Namespacing](../ug/namespacing.md) for more information on namespaces.

    """,
    attrs = dict(
        rule_options,
        _rule = attr.string(default = "ocaml_ns_library")
    ),
    cfg     = nslib_in_transition,
    provides = [OcamlNsMarker, OcamlLibraryMarker, OcamlProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
