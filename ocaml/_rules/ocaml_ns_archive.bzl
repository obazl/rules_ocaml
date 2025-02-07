load("//providers:ocaml.bzl",
     "OcamlProvider",
     "OcamlArchiveMarker",
     "OcamlNsMarker")

load(":options.bzl", "options", "options_ns_aggregators", "options_ns_opts")

# load("//ocaml/_transitions:out_transitions.bzl", "nsarchive_in_transition")
load("//ocaml/_transitions:in_transitions.bzl", "nslib_in_transition")

load(":impl_archive.bzl", "impl_archive")

load("@rules_ocaml//ocaml/_debug:colors.bzl",
     # "CCRED", "CCGRN", "CCBLU", "CCBLUBG",
     # "CCMAG", "CCMAGBG",
     # "CCCYN", "CCCYNBG",
     # "CCYEL", "CCUYEL", "CCYELBG", "CCYELBGH",
     "CCRESET",
     )

CCBLUCYN="\033[44m\033[36m"

#######################
def _ocaml_ns_archive_impl(ctx):

    # print("{c}ocaml_ns_archive: {m}{r}".format(
    #     c=CCBLUCYN,m=ctx.label,r=CCRESET))

    # if True: #  debug_tc:
    #     tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    #     print("BUILD TGT: {color}{lbl}{reset}".format(
    #         color=CCMAG, reset=CCRESET, lbl=ctx.label))
    #     print("  TC.NAME: %s" % tc.name)
    #     print("  TC.HOST: %s" % tc.host)
    #     print("  TC.TARGET: %s" % tc.target)
    #     print("  TC.COMPILER: %s" % tc.compiler.basename)

    return impl_archive(ctx) # , tc.target, tc, tc.compiler, [])

###############################
rule_options = options("ocaml")
rule_options.update(options_ns_aggregators())
# rule_options.update(options_ns_opts("ocaml"))

########################
ocaml_ns_archive = rule(
    implementation = _ocaml_ns_archive_impl,
    doc = """Generate a 'namespace' module. [User Guide](../ug/ocaml_ns.md).  Provides: [OcamlNsMarker](providers_ocaml.md#ocamlnsmoduleprovider).

    Deprecated.  Use ocaml_ns_library with 'archived = True' instead.

**NOTE** 'name' must be a legal OCaml module name string.  Leading underscore is illegal.

See [Namespacing](../ug/namespacing.md) for more information on namespaces.

    """,
    attrs = dict(
        rule_options,
        shared = attr.bool(
            doc = "True: build a shared lib (.cmxs)",
            default = False
        ),

        _rule = attr.string(default = "ocaml_ns_archive"),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    # cfg     = nsarchive_in_transition,
    cfg     = nslib_in_transition,
    provides = [OcamlNsMarker, OcamlArchiveMarker, OcamlProvider],
    executable = False,
    fragments = ["platform", "cpp"],
    host_fragments = ["platform",  "cpp"],
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)
