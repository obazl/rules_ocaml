load("//build:providers.bzl", "OCamlModuleProvider")

load("//build/_transitions:in_transitions.bzl", "module_in_transition")

load(":apis.bzl",
     "options",
     "options_pack_library",
     "options_ns_opts"
     )

load(":impl_pack_library.bzl", "impl_pack_library")

################################
rule_options = options("rules_ocaml")
rule_options.update(options_pack_library("ocaml"))
rule_options.update(options_ns_opts("ocaml"))

####################
ocaml_pack_library = rule(
    implementation = impl_pack_library,
    doc = """Compiles an OCaml "pack" module.""",
    attrs = dict(
        rule_options,
        _rule = attr.string( default = "ocaml_pack_library" ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    # cfg     = module_in_transition,
    provides = [OCamlModuleProvider],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std"],
)
