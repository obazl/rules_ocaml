load("@rules_ocaml//build:providers.bzl", "OCamlDepsProvider")
load("//build:providers.bzl",
     "OCamlLibraryProvider",
     "OCamlModuleProvider",
     "OcamlNsMarker",
     "OCamlNsResolverProvider")

load("//build/_transitions:in_transitions.bzl",
     "nslib_in_transition")

load("//build/_transitions:out_transitions.bzl",
     "ocaml_nslib_submodules_out_transition")

load("//build/_rules/ocaml_library:impl_archive.bzl", "impl_archive")
load("//build/_rules/ocaml_library:impl_library.bzl", "impl_library")

load("//build/_lib:options.bzl",
     "options",
     "options_ns_opts",
     "options_ns_aggregators")

###############################
def _ocaml_ns_library(ctx):

    if ctx.attr.archived:
        return impl_archive(ctx)
    else:
        return impl_library(ctx)

    # return impl_library(ctx)

################################
rule_options = options("rules_ocaml")
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
        archived = attr.bool(),
        _rule = attr.string(default = "ocaml_ns_library"),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    cfg     = nslib_in_transition,
    provides = [OcamlNsMarker, OCamlLibraryProvider, OCamlDepsProvider],
    executable = False,
    fragments = ["platform", "cpp"],
    host_fragments = ["platform",  "cpp"],
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)
