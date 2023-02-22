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

    # print("{c}ocaml_exec_module: {m}{r}".format(
    #     c=CCBLUBG,m=ctx.label,r=CCRESET))

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
        struct = attr.label(
            doc = "A single module (struct) source file label.",
            mandatory = True,
            allow_single_file = True # no constraints on extension
        ),

        ## we have both a public and a hidden ns resolver attribute.
        ## this one is for bottom-up namespacing:
        ns_resolver = attr.label(
            doc = """
NS resolver module for bottom-up namespacing. Modules may use this attribute to elect membership in a bottom-up namespace.
            """,
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            mandatory = False
        ),

        ## this one is for topdown-up namespacing:
        _ns_resolver = attr.label(
            doc = "NS resolver module for top-down namespacing",
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            ## @rules_ocaml//cfg/ns is a 'label_setting' whose value is an
            ## `ocaml_ns_resolver` rule. so this institutes a
            ## dependency on a resolver whose build params will be set
            ## dynamically using transition functions.
            default = "@rules_ocaml//cfg/ns:resolver",

            ## TRICKY BIT: if our struct is generated (e.g. by
            ## ocaml_lex), this transition will prevent ns renaming:
            # cfg = ocaml_module_deps_out_transition
        ),

        _rule = attr.string( default  = "ocaml_exec_module" ),
        _tags = attr.string_list( default  = ["ocaml", "exec"] ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
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

