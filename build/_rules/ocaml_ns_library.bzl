load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

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

load("//build/_lib:apis.bzl",
     "options",
     "options_ns_opts",
     "options_ns_aggregators")

load("@rules_ocaml//lib:colors.bzl",
     "CCRED", "CCRESET")

###############################
def _ocaml_ns_library(ctx):

    print("""

{c}WARNING{r}: ocaml_ns_library is DEPRECATED and will be removed in the next version of rules_ocaml. Please use ocaml_ns instead.
    """.format(
        c=CCRED, r=CCRESET)
    )

    # if ctx.attr.archived:
    #     return impl_archive(ctx)
    # else:
    #     return impl_library(ctx)

    ## target 'linkage' attr overrides hidden '_linkage'
    if ctx.attr.linkage:
        _linkage = ctx.attr.linkage
    elif ctx.attr._linkage[BuildSettingInfo].value == "none":
        _linkage = None
    else:
        _linkage = ctx.attr._linkage[BuildSettingInfo].value

    # print("{} linkage: {}, linklevel: {}".format(
    #         ctx.label, _linkage,
    #         ctx.attr._linklevel[BuildSettingInfo].value))

    if (ctx.attr._linklevel[BuildSettingInfo].value == 0):
        if _linkage == "static":
            return impl_archive(ctx, _linkage)
        elif _linkage == "shared":
            return impl_archive(ctx, _linkage)
        else:
            return impl_library(ctx, _linkage)
    else:
        if ctx.attr.linkage: # explicit attr forces issue
            return impl_archive(ctx, _linkage)
        else:
            return impl_library(ctx, _linkage)

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
