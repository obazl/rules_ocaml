load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider")

load("//ocaml/_transitions:transitions.bzl",
     "nslib_in_transition")

load("//ocaml/_transitions:ns_transitions.bzl",
     "ocaml_nslib_submodules_out_transition")

load(":impl_library.bzl", "impl_library")

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ns_aggregators")

###############################
def _ocaml_ns_library(ctx):

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    return impl_library(ctx, tc.emitting, tc.compiler, [])

################################
rule_options = options("ocaml")
rule_options.update(options_ns_aggregators())
# rule_options.update(options_ns_opts("ocaml"))

################
ocaml_ns_library = rule(
    implementation = _ocaml_ns_library,
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
    toolchains = ["@rules_ocaml//toolchain:type"],
)
