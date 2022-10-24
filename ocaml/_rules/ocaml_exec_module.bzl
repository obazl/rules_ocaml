## convenience rule. exact same as ocaml_module, just provided to
## allow users more expressivity w/r/t building executables

load("//ocaml:providers.bzl",
     "OcamlModuleMarker",
     "OcamlNsResolverProvider")

load("//ocaml/_transitions:in_transitions.bzl", "module_in_transition")

load(":options.bzl",
     "options",
     "options_module",
     "options_ns_opts",
     "options_ppx")

load(":impl_module.bzl", "impl_module")

load("@rules_ocaml//ocaml/_debug:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCBLUBG", "CCMAG", "CCCYN", "CCRESET")

###############################
def _ocaml_exec_module(ctx):

    print("{c}ocaml_exec_module: {m}{r}".format(
        c=CCBLUBG,m=ctx.label,r=CCRESET))

    return impl_module(ctx) # , tc.target, tc.compiler, [])

################################
rule_options = options("ocaml")
rule_options.update(options_module("ocaml"))
# rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

####################
ocaml_exec_module = rule(
    implementation = _ocaml_exec_module,
 # Provides: [OcamlModuleMarker](providers_ocaml.md#ocamlmoduleprovider).
    doc = """
    See documentation for ocaml_module.
    """,
    attrs = dict(
        rule_options,
        _rule = attr.string( default  = "ocaml_exec_module" ),
        _tags = attr.string_list( default  = ["ocaml", "exec"] ),
    ),

    fragments = ["platform", "cpp"],
    host_fragments = ["platform",  "cpp"],
    incompatible_use_toolchain_transition = True,
    cfg     = module_in_transition,
    provides = [OcamlModuleMarker],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)

