load("//ocaml:providers.bzl",
     "OpamDepsProvider",
     "PpxModuleProvider")

load("options.bzl",
     "options",
     "options_module",
     "options_ns_opts",
     "options_ppx")

load(":impl_module.bzl", "impl_module")

load("//ocaml/_transitions:transitions.bzl",
     "module_in_transition")

################################
rule_options = options("ppx")
rule_options.update(options_module("ppx"))
rule_options.update(options_ns_opts("ppx"))
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
        _rule = attr.string( default = "ppx_module" ),
    ),
    cfg     = module_in_transition,
    provides = [PpxModuleProvider, OpamDepsProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
