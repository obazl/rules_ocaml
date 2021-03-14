load("//ocaml:providers.bzl",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("options.bzl",
     "options",
     "options_module",
     "options_ns_opts",
     "options_ppx")

load(":impl_module.bzl", "impl_module")

load("//ocaml/_transitions:transitions.bzl",
     "module_in_transition")
# load("//ppx/_transitions:transitions.bzl",
#      "ppx_module_in_transition")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

################################
rule_options = options("ocaml")
rule_options.update(options_module("ocaml"))
rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

##################
ppx_module = rule(
    implementation = impl_module,
    doc = """Compiles a Ppx module.

TODO: finish docstring

    """,
    attrs = dict(
        rule_options,
        deps_adjunct = attr.string_list(
            doc = "List of adjunct deps.",
        ),
        deps_adjunct_opam = attr.string_list(
            doc = "List of OPAM adjunct deps.",
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        # gen = attr.label_keyed_string_dict(
        #     doc = "Experimental. Key is executable target, value is command-line arg string."
        # ),
        _rule = attr.string( default = "ppx_module" ),
    ),
    cfg     = module_in_transition,
    provides = [DefaultInfo, PpxModuleProvider, OpamDepsProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
