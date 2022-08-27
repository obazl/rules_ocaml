load("//ocaml:providers.bzl", "OcamlModuleMarker")

load("//ocaml/_transitions:transitions.bzl", "module_in_transition")

load(":options.bzl",
     "options",
     "options_pack_library",
     "options_ns_opts"
     )

load(":impl_pack_library.bzl", "impl_pack_library")

################################
rule_options = options("ocaml")
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
    provides = [OcamlModuleMarker],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std"],
)
