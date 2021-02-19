load("//ocaml:providers.bzl",
     "OcamlSignatureProvider",
     "OcamlNsEnvProvider",
     "OpamPkgInfo",
     "OpamDepsProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("options.bzl", "options", "options_module", "options_ns", "options_ppx")

load(":x_impl_module.bzl", "impl_module")

load("//ppx/_transitions:transitions.bzl", "ppx_mode_transition")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

################################
rule_options = options("@ppx")
rule_options.update(options_module("@ppx"))
rule_options.update(options_ns("@ppx"))
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
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        _rule = attr.string( default = "ppx_module" ),
    ),
    cfg     = ppx_mode_transition,
    provides = [DefaultInfo, PpxModuleProvider, OpamDepsProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
